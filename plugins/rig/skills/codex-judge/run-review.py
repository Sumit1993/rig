#!/usr/bin/env python3
"""Bounded independent review; protocol and limits are in codex-judge/SKILL.md."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError

MODEL = "gpt-6.1-sol"
AI_CONTEXT = Path.home() / "ai-context"
HERE = Path(__file__).resolve().parent


def save(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n")


def git(worktree, *args):
    return subprocess.check_output(
        ["git", "-C", str(worktree), *args], text=True, stderr=subprocess.PIPE
    ).strip()


def target(worktree):
    return {"commit": git(worktree, "rev-parse", "HEAD"),
            "status": git(worktree, "status", "--porcelain", "--untracked-files=all")}


def validate(result):
    schema = json.loads((HERE / "result.schema.json").read_text())
    Draft202012Validator(schema).validate(result)
    objections = result["objections"]
    ids = [item["id"] for item in objections]
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate objection IDs")
    open_items = [item for item in objections if item["status"] == "open"]
    blocking = any(item["severity"] == "blocking" for item in open_items)
    material = any(item["severity"] == "material" for item in open_items)
    verdict = result["verdict"]
    if not result["coverage_complete"] and verdict != "incomplete":
        raise ValueError("coverage gap requires incomplete verdict")
    if verdict != "incomplete":
        expected = "blocked" if blocking else "risks" if material else "survived"
        if verdict != expected:
            raise ValueError("verdict contradicts open objections")


def run(args):
    packet = args.packet.resolve(strict=True)
    worktree = args.worktree.resolve(strict=True)
    out = args.run_dir.resolve()
    if not out.is_relative_to(AI_CONTEXT.resolve()):
        raise ValueError("run directory must be under ~/ai-context")
    if out.is_relative_to(worktree):
        raise ValueError("run directory must be outside review worktree")
    if not 0 < args.timeout <= 3600:
        raise ValueError("timeout must be greater than zero and at most 3600 seconds")
    if git(worktree, "rev-parse", "--show-toplevel") != str(worktree):
        raise ValueError("worktree must name the repository root")
    git_dir = Path(git(worktree, "rev-parse", "--absolute-git-dir"))
    common_dir = Path(git(worktree, "rev-parse", "--git-common-dir"))
    if not common_dir.is_absolute():
        common_dir = worktree / common_dir
    if git_dir.resolve() == common_dir.resolve() or ".claude/worktrees/" not in str(worktree) + "/":
        raise ValueError("review requires a dedicated .claude/worktrees worktree")
    before = target(worktree)
    if before["status"]:
        raise ValueError("review target must be clean; commit a snapshot first")
    out.mkdir(parents=True, exist_ok=False)
    packet_text = packet.read_text()
    prompt = (HERE / "review-contract.md").read_text() + "\n" + packet_text
    prompt_path = out / "prompt.md"
    prompt_path.write_text(prompt)
    (out / "packet.md").write_text(packet_text)
    candidate = out / "candidate.json"
    command = ["codex", "--no-daemon", "--search", "--ask-for-approval", "never", "exec",
               "--ignore-user-config", "--ephemeral", "-C", str(worktree), "-m", MODEL,
               "-c", f"model_reasoning_effort={args.effort}", "--sandbox", "read-only",
               "--json", "--output-schema", str(HERE / "result.schema.json"),
               "-o", str(candidate), "-"]
    save(out / "metadata.json", {"model": MODEL, "effort": args.effort,
         "target": before, "worktree": str(worktree), "packet": str(packet),
         "prompt_sha256": hashlib.sha256(prompt.encode()).hexdigest(),
         "argv": command, "timeout_seconds": args.timeout})
    status = {"state": "failed", "target_commit": before["commit"], "exit_code": None}
    started = time.monotonic()
    try:
        with (out / "events.jsonl").open("w") as events, (out / "stderr.log").open("w") as errors:
            proc = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=events,
                                    stderr=errors, text=True, start_new_session=True)
            try:
                proc.communicate(prompt, timeout=args.timeout)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(proc.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass
                finally:
                    try:
                        os.killpg(proc.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    proc.wait()
                raise TimeoutError("review timed out; owned process group terminated")
        status["exit_code"] = proc.returncode
        if proc.returncode != 0:
            raise RuntimeError(f"Codex exited {proc.returncode}; independent review incomplete")
        if target(worktree) != before:
            raise ValueError("review target changed during the run")
        result = json.loads(candidate.read_text())
        validate(result)
        candidate.rename(out / "result.json")
        status["verdict"] = result["verdict"]
        status["state"] = "incomplete" if result["verdict"] == "incomplete" else "completed"
    except Exception as error:
        status["error"] = error.message if isinstance(error, ValidationError) else str(error)
    finally:
        status["elapsed_seconds"] = round(time.monotonic() - started, 3)
        save(out / "status.json", status)
    print(json.dumps(status))
    return 0 if status["state"] == "completed" else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--packet", type=Path, required=True)
    parser.add_argument("--worktree", type=Path, required=True)
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--effort", choices=["high", "xhigh"], default="high")
    parser.add_argument("--timeout", type=float, default=1200)
    args = parser.parse_args()
    try:
        return run(args)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"dispatch failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
