#!/usr/bin/env python3
"""Start a Codex desktop thread with no click, or queue a message to one; see codex-desktop §4."""
import argparse
import json
import os
from pathlib import Path
import subprocess


def codex_exe():
    home = Path(os.environ.get("WIN_HOME", f"/mnt/c/Users/{os.environ['USER']}"))
    found = sorted(home.glob("AppData/Local/OpenAI/Codex/bin/*/codex.exe"), key=lambda p: p.stat().st_mtime)
    if not found:
        raise FileNotFoundError("no codex.exe under the Codex desktop install")
    return str(found[-1])


def rpc(calls, exe=None):
    """Run JSON-RPC calls against a private stdio app-server; a call's params may be a function of earlier results."""
    proc = subprocess.Popen([exe or codex_exe(), "app-server", "--stdio"], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)

    def send(message):
        proc.stdin.write(json.dumps(message) + "\n")
        proc.stdin.flush()

    def request(i, method, params):
        send({"jsonrpc": "2.0", "id": i, "method": method, "params": params})
        for line in proc.stdout:
            message = json.loads(line)
            if message.get("id") == i:
                if "error" in message:
                    raise RuntimeError(f"{method}: {message['error']}")
                return message["result"]
        raise RuntimeError(f"{method}: app-server exited")

    try:
        # The desktop app only follows threads whose originator is its own.
        results = [request(0, "initialize", {"clientInfo": {"name": "codex_desktop", "title": None, "version": "1"}})]
        send({"jsonrpc": "2.0", "method": "initialized"})
        for i, (method, params) in enumerate(calls, 1):
            results.append(request(i, method, params(results) if callable(params) else params))
        return results
    finally:
        proc.stdin.close()
        proc.wait(timeout=30)


def new_thread(name, workspace, exe=None, opener=subprocess.run):
    tid = lambda r: r[1]["thread"]["id"]
    results = rpc([
        ["thread/start", {"cwd": workspace, "sandbox": "workspace-write", "approvalsReviewer": "auto_review"}],
        ["thread/name/set", lambda r: {"threadId": tid(r), "name": name}],
        # A thread with no message is never written to disk; this one makes it persist without a model turn.
        ["thread/inject_items", lambda r: {"threadId": tid(r), "items": [{"type": "message", "role": "user",
            "content": [{"type": "input_text", "text": f"Thread '{name}' opened by rig. Tasks arrive as queued messages."}]}]}],
    ], exe)
    thread_id = tid(results)
    # Mounting the thread's route is what makes the app consume its queue.
    opener(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
            f"Start-Process 'codex://threads/{thread_id}'"], check=True, timeout=30)
    return thread_id


def queue(thread_id, message, exe=None):
    subprocess.run([exe or codex_exe(), "queue", "--thread", thread_id, "--message", message],
                   check=True, timeout=60, stdout=subprocess.DEVNULL)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    new = sub.add_parser("new", help="start and mount a thread; prints its id")
    new.add_argument("--name", required=True)
    new.add_argument("--workspace", required=True, help="native Windows path of the trusted lane folder")
    send = sub.add_parser("send", help="queue a message to a thread")
    send.add_argument("--thread", required=True)
    send.add_argument("--message-file", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == "new":
            print(new_thread(args.name, args.workspace))
        else:
            queue(args.thread, args.message_file.read_text())
            print(f"queued to {args.thread}")
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        parser.exit(1, f"codex_thread failed: {error}\n")


if __name__ == "__main__":
    main()
