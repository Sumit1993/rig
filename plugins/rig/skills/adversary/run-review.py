#!/usr/bin/env python3
"""Bounded adversary-seat judgment; protocol and limits are in adversary/SKILL.md."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import signal
import subprocess
import sys
import time

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError

DEFAULT_MODEL = "gpt-6.1-sol"
CLAUDE_MODEL = "opus"
CLAUDE_TOOLS = "Read,Grep,Glob,WebSearch,WebFetch"
EFFORTS = ("high", "xhigh", "max")
AI_CONTEXT = Path.home() / "ai-context"
HERE = Path(__file__).resolve().parent
# The packet and prior ledger arrive in the prompt, so citing them needs no tool call.
PROMPT_FILES = ("packet.md", "previous-result.json")
NON_TOOL_ITEMS = {"agent_message", "reasoning", "todo_list", "error"}


def save(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n")


def git(worktree, *args):
    return subprocess.check_output(
        ["git", "-C", str(worktree), *args], text=True, stderr=subprocess.PIPE
    ).strip()


def target(worktree):
    return {"commit": git(worktree, "rev-parse", "HEAD"),
            "status": git(worktree, "status", "--porcelain", "--untracked-files=all")}


def validate(result, previous=None, ledger=False):
    schema = json.loads((HERE / "result.schema.json").read_text())
    Draft202012Validator(schema).validate(result)
    objections = result["objections"]
    ids = [item["id"] for item in objections]
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate objection IDs")
    if previous is not None:
        prior_ids = {item["id"] for item in previous["objections"]}
        if prior_ids - set(ids):
            raise ValueError("missing prior objections: " + ", ".join(sorted(prior_ids - set(ids))))
    prior_ids = {item["id"] for item in previous["objections"]} if previous else set()
    for item in objections:
        if item["status"] != "open" and not ledger and item["id"] not in prior_ids:
            raise ValueError(f"{item['id']} is {item['status']} without a prior ledger entry")
        for field in ("scenario", "evidence", "falsification_check"):
            if not item[field].strip():
                raise ValueError(f"{item['id']} has empty {field}")
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
    if verdict == "survived" and not any(s.strip() for s in result["sources"]["inside"] + result["sources"]["outside"]):
        raise ValueError("survived verdict names no sources")


def terminate(proc):
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
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass


def integrations(worktree):
    options = ["-c", "features.plugins=false", "-c", "features.apps=false",
               "-c", "features.enable_mcp_apps=false"]
    prefix = ["codex", "--no-daemon", "-C", str(worktree)]
    def servers(overrides):
        output = subprocess.check_output(prefix + overrides + ["mcp", "list", "--json"],
                                         cwd=worktree, text=True, stderr=subprocess.PIPE, timeout=30)
        rows = json.loads(output)
        if not isinstance(rows, list) or any(not isinstance(r.get("name"), str) for r in rows):
            raise ValueError("unrecognized MCP discovery result")
        return rows
    for server in servers(options):
        if not re.fullmatch(r"[A-Za-z0-9_-]+", server["name"]):
            raise ValueError("MCP name cannot be safely disabled with CLI dotted overrides")
        options += ["-c", "mcp_servers." + server["name"] + ".enabled=false"]
    if any(server.get("enabled") is not False for server in servers(options)):
        raise ValueError("MCP isolation could not be verified")
    return options


def codex_quota():
    unknown = {"line": "unknown: quota check failed", "exhausted": None}
    try:
        done = subprocess.run([sys.executable, str(HERE / "codex-quota.py"), "check", "--json"],
                              capture_output=True, text=True, timeout=40)
        quota = json.loads(done.stdout)
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return unknown
    return quota if isinstance(quota, dict) else unknown


def codex_command(worktree, model, effort, candidate, packet_mode):
    return ["codex", "--no-daemon", "--search", "--ask-for-approval", "never", "exec",
            "--ephemeral", "-C", str(worktree),
            *(["--skip-git-repo-check"] if packet_mode else []), "-m", model,
            "-c", f"model_reasoning_effort={effort}", "--sandbox", "read-only",
            "--json", "--output-schema", str(HERE / "result.schema.json"),
            "-o", str(candidate), "-"]


def claude_command(effort):
    # stream-json (not json) so tool calls are visible to the zero-tool and sources checks;
    # its final `result` line is the same envelope, with `structured_output`.
    schema = json.dumps(json.loads((HERE / "result.schema.json").read_text()), separators=(",", ":"))
    return ["claude", "-p", "--model", CLAUDE_MODEL, "--effort", effort,
            "--tools", CLAUDE_TOOLS, "--allowedTools", CLAUDE_TOOLS, "--strict-mcp-config",
            "--no-session-persistence", "--output-format", "stream-json", "--verbose",
            "--json-schema", schema]


def read_events(path):
    events = []
    for line in path.read_text(errors="replace").splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if isinstance(event, dict):
            events.append(event)
    return events


def refusal(node):
    if isinstance(node, dict):
        if node.get("codex_error_info"):
            return f"{node['codex_error_info']}: {node.get('message', '')}".strip()
        node = list(node.values())
    if isinstance(node, list):
        for value in node:
            found = refusal(value)
            if found:
                return found
    return None


def codex_tools(events):
    """Tool items of a codex exec --json stream, or a failure reason."""
    for event in events:
        reason = refusal(event)
        if reason:
            raise RuntimeError(f"Codex reported an error ({reason}); judgment incomplete")
    return [e["item"] for e in events if e.get("type") == "item.completed"
            and isinstance(e.get("item"), dict) and e["item"].get("type") not in NON_TOOL_ITEMS]


def claude_run(events):
    """(tool records, result envelope) of a claude stream-json run."""
    tools, envelope = [], None
    for event in events:
        content = (event.get("message") or {}).get("content") if isinstance(event.get("message"), dict) else None
        for block in content if isinstance(content, list) else []:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "tool_use" and block.get("name") != "StructuredOutput":
                tools.append(block)
            elif block.get("type") == "tool_result":
                tools.append(block)
        if event.get("type") == "result":
            envelope = event
    if envelope is None:
        raise RuntimeError("claude run left no result envelope; judgment incomplete")
    if envelope.get("is_error") or not isinstance(envelope.get("structured_output"), dict):
        raise RuntimeError(f"claude run ended {envelope.get('subtype')} without structured output; judgment incomplete")
    return tools, envelope


def source_refs(entry):
    refs = re.findall(r"https?://[^\s)\]>'\"]+", entry)
    rest = re.sub(r"https?://[^\s)\]>'\"]+", " ", entry)
    for token in re.split(r"[\s\[\](),;`'\"]+", rest):
        token = re.sub(r"(:[0-9][0-9,–—-]*)+$", "", token.rstrip(".,:;"))
        name = token.rsplit("/", 1)[-1]
        if token.startswith(("/", "~/", "./", "../")) or re.fullmatch(r"[\w-]{2,}(\.[\w-]+)*\.[A-Za-z][A-Za-z0-9]{0,4}", name):
            refs.append(token)
    return [r.rstrip(".,:;") for r in refs if r.strip("./~")]


def unmatched_sources(result, tool_records):
    """Sources entries naming a path or URL that no tool call touched."""
    seen = json.dumps(tool_records) + " " + " ".join(PROMPT_FILES)
    def touched(ref):
        if ref.startswith("http"):
            bare = re.sub(r"(\.md)?/?(#.*)?$", "", ref)
            return bare in seen
        return ref in seen or Path(ref).name in seen
    missing = []
    for entry in result["sources"]["inside"] + result["sources"]["outside"]:
        refs = source_refs(entry)
        if refs and not all(touched(ref) for ref in refs):
            missing.append(entry)
    return missing


def run(args):
    holder = getattr(args, "holder", "codex")
    model = getattr(args, "model", DEFAULT_MODEL) if holder == "codex" else CLAUDE_MODEL
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:-]*", model):
        raise ValueError("invalid model name")
    if args.effort not in EFFORTS:
        raise ValueError("effort must be one of " + ", ".join(EFFORTS))
    packet = args.packet.resolve(strict=True)
    worktree = args.worktree.resolve(strict=True) if args.worktree else None
    out = args.run_dir.resolve()
    if not out.is_relative_to(AI_CONTEXT.resolve()):
        raise ValueError("run directory must be under ~/ai-context")
    if worktree and out.is_relative_to(worktree):
        raise ValueError("run directory must be outside review worktree")
    if not 0 < args.timeout <= 3600:
        raise ValueError("timeout must be greater than zero and at most 3600 seconds")
    expected = {}
    if worktree is None:
        if args.base or args.head:
            raise ValueError("base/head require --worktree")
    else:
        if git(worktree, "rev-parse", "--show-toplevel") != str(worktree):
            raise ValueError("worktree must name the repository root")
        git_dir = Path(git(worktree, "rev-parse", "--absolute-git-dir"))
        common_dir = Path(git(worktree, "rev-parse", "--git-common-dir"))
        if not common_dir.is_absolute():
            common_dir = worktree / common_dir
        if git_dir.resolve() == common_dir.resolve():
            raise ValueError("review requires a dedicated git worktree, not the main checkout")
        expected = {}
        for name, value in [("base", args.base), ("head", args.head)]:
            if not value or len(value) != 40 or any(c not in "0123456789abcdef" for c in value):
                raise ValueError("expected base/head must be full commit SHAs")
            expected[name] = git(worktree, "rev-parse", "--verify", value + "^{commit}")
    previous = None
    if args.previous_result is not None:
        previous = json.loads(args.previous_result.read_text())
        validate(previous, ledger=True)
    packet_text = packet.read_text()
    before = target(worktree) if worktree else {"packet_sha256": hashlib.sha256(packet_text.encode()).hexdigest()}
    if worktree and before["commit"] != expected["head"]:
        raise ValueError("worktree HEAD differs from requested review target")
    if worktree and before["status"]:
        raise ValueError("review target must be clean; commit a snapshot first")
    out.mkdir(parents=True, exist_ok=False)
    if not worktree:
        worktree = out / "evidence"
        worktree.mkdir()
        (worktree / "packet.md").write_text(packet_text)
        expected = {"mode": "packet", **before}
    packet_mode = "packet_sha256" in before
    prompt = ((HERE / "review-contract.md").read_text() + "\nVerified review identity:\n"
              + json.dumps(expected) + "\n" + packet_text)
    if previous is not None:
        save(out / "previous-result.json", previous)
        prompt += "\nPrevious objection ledger (every ID requires a disposition):\n" + json.dumps(previous)
    prompt_path = out / "prompt.md"
    prompt_path.write_text(prompt)
    (out / "packet.md").write_text(packet_text)
    candidate = out / "candidate.json"
    if holder == "codex":
        command = codex_command(worktree, model, args.effort, candidate, packet_mode)
    else:
        command = claude_command(args.effort)
    status = {"state": "failed", "holder": holder, "target_commit": before.get("commit"), "exit_code": None}
    started = time.monotonic()
    proc = None
    old_handlers = {}
    def cancelled(signum, frame):
        raise InterruptedError(f"review cancelled by signal {signum}")
    try:
        for sig in (signal.SIGINT, signal.SIGTERM):
            old_handlers[sig] = signal.signal(sig, cancelled)
        if holder == "codex":
            quota = codex_quota()
            status["quota"] = quota.get("line")
            if quota.get("exhausted"):
                raise RuntimeError(f"Codex quota {quota['line']}; independent review not launched")
            command[1:1] = integrations(worktree)
        metadata = {"holder": holder, "model": model, "effort": args.effort,
                    "target": before, "expected": expected, "worktree": str(worktree), "packet": str(packet),
                    "prompt_sha256": hashlib.sha256(prompt.encode()).hexdigest(),
                    "argv": command, "timeout_seconds": args.timeout}
        save(out / "metadata.json", metadata)

        with (out / "events.jsonl").open("w") as events, (out / "stderr.log").open("w") as errors:
            proc = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=events, cwd=worktree,
                                    stderr=errors, text=True, start_new_session=True)
            try:
                proc.communicate(prompt, timeout=args.timeout)
            except subprocess.TimeoutExpired:
                raise TimeoutError("review timed out; owned process group terminated")
            finally:
                terminate(proc)
        status["exit_code"] = proc.returncode
        if proc.returncode != 0:
            if holder == "codex":
                # A usage limit hit mid-run reads as a generic exit; the quota names it and its reset.
                status["quota"] = codex_quota().get("line")
            raise RuntimeError(f"{holder} exited {proc.returncode} (quota {status.get('quota')}); independent review incomplete")
        if (not packet_mode and target(worktree) != before) or (packet_mode and
            hashlib.sha256((worktree / "packet.md").read_bytes()).hexdigest() != before["packet_sha256"]):
            raise ValueError("review target changed during the run")
        events = read_events(out / "events.jsonl")
        if holder == "codex":
            tools = codex_tools(events)
        else:
            tools, envelope = claude_run(events)
            metadata["resolved_model"] = sorted(envelope.get("modelUsage") or {}) or None
            save(out / "metadata.json", metadata)
            save(candidate, envelope["structured_output"])
        if not tools:
            raise RuntimeError(f"{holder} completed with zero tool calls; judgment incomplete")
        result = json.loads(candidate.read_text())
        validate(result, previous)
        candidate.rename(out / "result.json")
        status["verdict"] = result["verdict"]
        status["unmatched_sources"] = unmatched_sources(result, tools)
        if result["verdict"] == "survived" and status["unmatched_sources"]:
            status["verdict"] = "incomplete"
            status["downgraded"] = "survived verdict cites sources no tool call touched"
        status["state"] = "incomplete" if status["verdict"] == "incomplete" else "completed"
    except Exception as error:
        status["error"] = error.message if isinstance(error, ValidationError) else str(error)
    finally:
        if proc is not None and proc.poll() is None:
            terminate(proc)
        for sig, handler in old_handlers.items():
            signal.signal(sig, handler)
        status["elapsed_seconds"] = round(time.monotonic() - started, 3)
        save(out / "status.json", status)
    print(json.dumps(status))
    return 0 if status["state"] == "completed" else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--packet", type=Path, required=True)
    parser.add_argument("--worktree", type=Path, help="Optional frozen Git target; omit for self-contained ideas/plans/specs")
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--base", help="Full immutable base commit SHA")
    parser.add_argument("--head", help="Full immutable requested target SHA")
    parser.add_argument("--previous-result", type=Path, help="Validated previous ledger for a rebuttal")
    parser.add_argument("--holder", choices=["codex", "claude"], default="codex",
                        help="Seat holder: codex (default) or claude when Codex is unavailable")
    parser.add_argument("--model", default=os.environ.get("RIG_CODEX_MODEL", DEFAULT_MODEL),
                        help="Codex model name; defaults to RIG_CODEX_MODEL or gpt-6.1-sol")
    parser.add_argument("--effort", choices=EFFORTS, default=os.environ.get("RIG_ADVERSARY_EFFORT", "high"),
                        help="Operator override only; defaults to RIG_ADVERSARY_EFFORT or high")
    parser.add_argument("--timeout", type=float, default=2400)
    args = parser.parse_args()
    try:
        return run(args)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"dispatch failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
