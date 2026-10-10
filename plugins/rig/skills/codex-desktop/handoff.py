#!/usr/bin/env python3
"""Prepare a supported desktop composer handoff; see codex-desktop §3."""
import argparse
import base64
import hashlib
import json
import os
import shlex
from pathlib import Path
import subprocess
from urllib.parse import urlencode


MENTIONS = {"computer": ("@Computer", "Computer Use"), "browser": ("@Browser", "Browser")}


def ask_back(directory, session=None, cwd=None):
    """The command a Codex thread runs to ask the dispatching Claude session a question; empty outside one."""
    session = session or os.environ.get("CLAUDE_CODE_SESSION_ID")
    if not session:
        return ""
    # Answer-only: no tools and no MCP servers, so a thread reading untrusted pages can ask but never act.
    script = (f"cd {shlex.quote(str(cwd or os.getcwd()))} && claude -p --resume {shlex.quote(session)} --fork-session "
              f"--tools '' --strict-mcp-config < {shlex.quote(f'{directory}/question.md')}")
    # Codex runs commands in PowerShell, whose single-quoted strings escape a quote by doubling it.
    return (f" To ask the Claude session that sent this task a question, write it to question.md in that folder and run "
            f"`wsl.exe -e bash -lc '{script.replace(chr(39), chr(39) * 2)}'`; its output is the answer.")


def prepare(packet, directory, open_app=False, report="report.md", surface="computer"):
    mention, plugin = MENTIONS[surface]
    packet_bytes = packet.resolve(strict=True).read_bytes()
    directory = directory.resolve()
    if not str(directory).startswith("/mnt/"):
        raise ValueError("windows-dir must be on a mounted Windows drive")
    native = subprocess.check_output(["wslpath", "-w", str(directory)], text=True).strip()
    if not (len(native) > 3 and native[1:3] == ":\\"):
        raise ValueError("windows-dir must resolve to a native drive path")
    directory.mkdir(parents=True, exist_ok=False)
    (directory / "packet.md").write_bytes(packet_bytes)
    title = next((line[2:].strip() for line in packet_bytes.decode("utf-8", "replace").splitlines()
                  if line.startswith("# ")), packet.stem)
    prompt = (
        f"{mention} Perform the scoped desktop task \"{title}\". The packet below is the task, and its "
        f"allowed actions are my authorization; a copy is packet.md in {native}. "
        f"Follow your installed {plugin} skill and policy. "
        "For app testing, observe the actual app/build and distinguish expected from observed behavior. "
        "Do not change source code or operate the Codex app UI. Stop on unavailable "
        "permissions/authentication, unclear mutation authority, locked desktop or, for app testing, a wrong build. "
        f"Write {report} in that folder and available window screenshots under its evidence/ using normal file tools, "
        "decoding a screenshot data URL to a file yourself and listing an MD5 of every evidence file, which must all differ; "
        "include steps, outcomes, failures, blocked/untried steps and, for app testing, build identity. "
        "If file output is unavailable, return the report in chat and say so."
        + ask_back(directory) +
        # The approval reviewer weighs only user messages, so the packet's permissions travel inline.
        "\n\n---\n\n" + packet_bytes.decode("utf-8", "replace")
    )
    link = "codex://new?" + urlencode({"path": native, "prompt": prompt})
    (directory / "prompt.txt").write_text(prompt + "\n")
    (directory / "open-link.txt").write_text(link + "\n")
    status = {"state": "prepared", "title": title, "packet_sha256": hashlib.sha256(packet_bytes).hexdigest(),
              "windows_workspace": native, "execution_verified": False}
    status_path = directory / "handoff.json"
    status_path.write_text(json.dumps(status, indent=2) + "\n")
    if open_app:
        # The link stays in open-link.txt: inline it and the encoded command can pass Windows' 32,767-char limit.
        link_file = (native.rstrip("\\") + "\\open-link.txt").replace("'", "''")
        script = f"Start-Process -FilePath (Get-Content -Raw -LiteralPath '{link_file}').Trim()"
        encoded = base64.b64encode(script.encode("utf-16le")).decode()
        try:
            subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive",
                            "-EncodedCommand", encoded], check=True, timeout=30)
        except (OSError, subprocess.SubprocessError) as error:
            status.update(state="open_failed", error=str(error))
            status_path.write_text(json.dumps(status, indent=2) + "\n")
            raise
        status["state"] = "open_requested"
    status_path.write_text(json.dumps(status, indent=2) + "\n")
    return status


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--packet", type=Path, required=True)
    parser.add_argument("--windows-dir", type=Path, required=True)
    parser.add_argument("--open", action="store_true")
    parser.add_argument("--report", default="report.md", help="file the packet asks Codex to write")
    parser.add_argument("--surface", choices=sorted(MENTIONS), default="computer", help="plugin the prompt mentions")
    args = parser.parse_args()
    try:
        print(json.dumps(prepare(args.packet, args.windows_dir, args.open, args.report, args.surface)))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(1, f"handoff failed: {error}\n")


if __name__ == "__main__":
    main()
