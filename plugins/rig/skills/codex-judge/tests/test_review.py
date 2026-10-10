import argparse
import contextlib
import io
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import signal
import threading
import time
import unittest
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[1] / "run-review.py"
spec = importlib.util.spec_from_file_location("judge", MODULE)
judge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(judge)


def result(verdict="survived", complete=True):
    return {"verdict": verdict, "coverage_complete": complete, "summary": "Fixture review",
            "objections": [], "survived_attacks": ["Fixture attack"], "unverified": [],
            "sources": {"inside": ["fixture.py:1"], "outside": []},
            "simplest_alternative": "none", "objection_to_recommendation": "Fixture limitation"}


class ReviewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.git("init", "-q")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "user.name", "Test")
        (self.repo / "source.txt").write_text("original\n")
        self.git("add", ".")
        self.git("commit", "-qm", "initial")
        self.worktree = self.repo / ".claude/worktrees/review"
        self.git("worktree", "add", "-q", "--detach", str(self.worktree))
        self.history = self.root / "ai-context"
        self.history.mkdir()
        self.packet = self.history / "packet.md"
        self.packet.write_text("Review the fixture.\n")
        self.head = judge.git(self.worktree, "rev-parse", "HEAD")
        self.previous = None
        self.out = self.history / "round-1"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        fake = self.bin / "codex"
        fake.write_text('''#!/usr/bin/env python3
import json, os, pathlib, subprocess, sys, time
args=sys.argv[1:]
mode=os.environ.get('REVIEW_MODE','success')
if args[:1]==['app-server']:
 for line in sys.stdin:
  if json.loads(line).get('id')==2: break
 used=100 if mode=='quota_exhausted' else 40
 print(json.dumps({'id':2,'result':{'ordinaryUsageAllowed':used<100,'rateLimits':{'primary':{'usedPercent':used,'windowDurationMins':300,'resetsAt':int(time.time())+3600},'secondary':{'usedPercent':50,'windowDurationMins':10080,'resetsAt':int(time.time())+86400}}}}),flush=True)
 sys.exit(0)
if 'mcp' in args:
 assert pathlib.Path.cwd() == pathlib.Path(args[args.index('-C')+1]), 'inventory used launcher cwd'
 if mode=='mcp_failure': sys.exit(7)
 disabled='mcp_servers.fixture.enabled=false' in args
 print(json.dumps([{'name':'fixture.dot' if mode=='unsafe_name' else 'fixture','enabled':False if disabled and mode!='unsafe_mcp' else True}]))
 sys.exit(0)
required=['--no-daemon','--search','--ask-for-approval','never','exec','--ephemeral','read-only','model_reasoning_effort=high','--json','features.plugins=false','features.apps=false','features.enable_mcp_apps=false','mcp_servers.fixture.enabled=false']
assert all(value in args for value in required), args
assert sys.stdin.read().startswith('You are the independent adversarial judge')
mode=os.environ.get('REVIEW_MODE','success')
if mode=='quota':
 print('quota exhausted',file=sys.stderr);sys.exit(9)
if mode=='timeout':
 child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)'])
 pathlib.Path(os.environ['CHILD_PID']).write_text(str(child.pid))
 time.sleep(30)
if mode=='changed':
 wt=args[args.index('-C')+1]
 pathlib.Path(wt,'source.txt').write_text('changed')
if mode=='changed_packet':
 pathlib.Path(args[args.index('-C')+1], 'packet.md').write_text('changed')
p=pathlib.Path(args[args.index('-o')+1])
p.write_text('{broken' if mode=='malformed' else os.environ['REVIEW_RESULT'])
print(json.dumps({'type':'turn.completed'}))
''')
        fake.chmod(0o755)
        self.addCleanup(patch.stopall)
        patch.object(judge, "AI_CONTEXT", self.history).start()
        patch.dict(os.environ, {"PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
                               "REVIEW_RESULT": json.dumps(result()),
                               "REVIEW_MODE": "success"}).start()

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.repo), *args], check=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def run_review(self, timeout=5, worktree=None):
        with contextlib.redirect_stdout(io.StringIO()):
            return judge.run(argparse.Namespace(packet=self.packet, worktree=worktree or self.worktree,
                             run_dir=self.out, effort="high", timeout=timeout, base=self.head,
                             head=self.head, previous_result=self.previous))

    def status(self):
        return json.loads((self.out / "status.json").read_text())

    def test_success_frozen_target_and_explicit_contract(self):
        self.assertEqual(self.run_review(), 0)
        self.assertEqual(self.status()["state"], "completed")
        self.assertTrue((self.out / "result.json").exists())
        self.assertFalse((self.out / "candidate.json").exists())
        meta = json.loads((self.out / "metadata.json").read_text())
        self.assertEqual(meta["model"], "gpt-6.1-sol")
        self.assertEqual(meta["effort"], "high")
        self.assertEqual(meta["target"]["status"], "")
        self.assertEqual((self.out / "packet.md").read_text(), self.packet.read_text())

    def test_packet_only_requires_no_git_and_binds_copied_proposal(self):
        with contextlib.redirect_stdout(io.StringIO()):
            code = judge.run(argparse.Namespace(packet=self.packet, worktree=None,
                run_dir=self.out, effort="high", timeout=5, base=None, head=None,
                previous_result=None, model="future-model"))
        self.assertEqual(code, 0)
        meta = json.loads((self.out / "metadata.json").read_text())
        self.assertEqual(meta["model"], "future-model")
        self.assertEqual(meta["expected"]["mode"], "packet")
        self.assertIn("--skip-git-repo-check", meta["argv"])
        self.assertEqual((self.out / "evidence/packet.md").read_text(), self.packet.read_text())

    def test_changed_packet_invalidates_concept_review(self):
        os.environ["REVIEW_MODE"] = "changed_packet"
        with contextlib.redirect_stdout(io.StringIO()):
            code = judge.run(argparse.Namespace(packet=self.packet, worktree=None,
                run_dir=self.out, effort="high", timeout=5, base=None, head=None,
                previous_result=None))
        self.assertEqual(code, 1)
        self.assertFalse((self.out / "result.json").exists())
        self.assertIn("target changed", self.status()["error"])

    def test_packet_mode_rejects_git_identity(self):
        with self.assertRaisesRegex(ValueError, "require --worktree"):
            judge.run(argparse.Namespace(packet=self.packet, worktree=None,
                run_dir=self.out, effort="high", timeout=5, base=self.head, head=None,
                previous_result=None))

    def test_quota_has_no_fallback_or_valid_result(self):
        os.environ["REVIEW_MODE"] = "quota"
        self.assertEqual(self.run_review(), 1)
        self.assertEqual(self.status()["exit_code"], 9)
        self.assertFalse((self.out / "result.json").exists())

    def test_exhausted_quota_prevents_launch(self):
        os.environ["REVIEW_MODE"] = "quota_exhausted"
        self.assertEqual(self.run_review(), 1)
        status = self.status()
        self.assertIsNone(status["exit_code"])
        self.assertIn("not launched", status["error"])
        self.assertTrue(status["quota"].startswith("exhausted until"))
        self.assertFalse((self.out / "events.jsonl").exists())

    def test_usable_quota_is_recorded(self):
        self.assertEqual(self.run_review(), 0)
        self.assertTrue(self.status()["quota"].startswith("usable: 5h 40%"))

    def test_malformed_and_schema_invalid_output_fail(self):
        for mode, response in [("malformed", result()), ("success", {"verdict": "survived"})]:
            with self.subTest(mode=mode):
                self.out = self.history / mode
                os.environ["REVIEW_MODE"] = mode
                os.environ["REVIEW_RESULT"] = json.dumps(response)
                self.assertEqual(self.run_review(), 1)
                self.assertFalse((self.out / "result.json").exists())

    def test_incomplete_is_valid_but_not_completed(self):
        os.environ["REVIEW_RESULT"] = json.dumps(result("incomplete", False))
        self.assertEqual(self.run_review(), 1)
        self.assertEqual(self.status()["state"], "incomplete")
        self.assertTrue((self.out / "result.json").exists())

    def test_material_coverage_gap_cannot_be_clean(self):
        os.environ["REVIEW_RESULT"] = json.dumps(result("survived", False))
        self.assertEqual(self.run_review(), 1)
        self.assertIn("coverage gap", self.status()["error"])

    def test_changed_target_invalidates_review(self):
        os.environ["REVIEW_MODE"] = "changed"
        self.assertEqual(self.run_review(), 1)
        self.assertIn("target changed", self.status()["error"])
        self.assertFalse((self.out / "result.json").exists())

    def test_dirty_and_main_checkouts_rejected_before_launch(self):
        with self.assertRaisesRegex(ValueError, "dedicated"):
            self.run_review(worktree=self.repo)
        (self.worktree / "new.txt").write_text("untracked")
        with self.assertRaisesRegex(ValueError, "clean"):
            self.run_review()
        self.assertFalse(self.out.exists())

    def test_existing_run_is_never_overwritten(self):
        self.out.mkdir()
        sentinel = self.out / "status.json"
        sentinel.write_text("old")
        with self.assertRaises(FileExistsError):
            self.run_review()
        self.assertEqual(sentinel.read_text(), "old")

    def test_timeout_terminates_owned_descendant(self):
        os.environ["REVIEW_MODE"] = "timeout"
        pidfile = self.history / "child.pid"
        os.environ["CHILD_PID"] = str(pidfile)
        self.assertEqual(self.run_review(timeout=1), 1)
        self.assertIn("timed out", self.status()["error"])
        pid = int(pidfile.read_text())
        stat = Path(f"/proc/{pid}/stat")
        self.assertTrue(not stat.exists() or stat.read_text().split()[2] == "Z")


    def test_wrong_expected_commit_is_rejected_before_launch(self):
        (self.worktree / "source.txt").write_text("new snapshot")
        subprocess.run(["git", "-C", str(self.worktree), "commit", "-qam", "snapshot"], check=True,
                       stdout=subprocess.PIPE)
        with self.assertRaisesRegex(ValueError, "requested review target"):
            self.run_review()
        self.assertFalse(self.out.exists())

    def test_rebuttal_cannot_drop_or_renumber_prior_ids(self):
        prior = result("blocked")
        objection = {"id": "OBJ-001", "status": "open", "severity": "blocking",
                     "category": "credible_risk", "title": "test", "scenario": "test",
                     "constraint": "test", "evidence": "test", "impact": "test",
                     "falsification_check": "test", "disposition_reason": "test"}
        prior["objections"] = [objection]
        judge.validate(prior)
        for response in [result(), {**prior, "objections": [{**objection, "id": "OBJ-002"}]}]:
            with self.assertRaisesRegex(ValueError, "missing prior"):
                judge.validate(response, prior)
        for status in ["fixed", "withdrawn"]:
            judge.validate({**result(), "objections": [{**objection, "status": status}]}, prior)
        self.previous = self.history / "prior.json"
        self.previous.write_text(json.dumps(prior))
        self.assertEqual(self.run_review(), 1)
        self.assertIn("missing prior", self.status()["error"])
        self.assertTrue((self.out / "previous-result.json").exists())
        self.assertIn("OBJ-001", (self.out / "prompt.md").read_text())

    def test_mcp_discovery_failure_or_enabled_server_prevents_launch(self):
        for mode in ["mcp_failure", "unsafe_mcp", "unsafe_name"]:
            self.out = self.history / mode
            os.environ["REVIEW_MODE"] = mode
            self.assertEqual(self.run_review(), 1)
            self.assertEqual(self.status()["state"], "failed")
            self.assertFalse((self.out / "result.json").exists())
            self.assertFalse((self.out / "events.jsonl").exists())

    def test_cancellation_terminates_owned_descendant_and_records_failure(self):
        os.environ["REVIEW_MODE"] = "timeout"
        pidfile = self.history / "child.pid"
        os.environ["CHILD_PID"] = str(pidfile)
        def interrupt():
            for _ in range(100):
                if pidfile.exists():
                    os.kill(os.getpid(), signal.SIGTERM)
                    return
                time.sleep(0.02)
        worker = threading.Thread(target=interrupt)
        worker.start()
        try:
            self.assertEqual(self.run_review(), 1)
        finally:
            worker.join()
        self.assertIn("cancelled", self.status()["error"])
        pid = int(pidfile.read_text())
        stat = Path(f"/proc/{pid}/stat")
        self.assertTrue(not stat.exists() or stat.read_text().split()[2] == "Z")

    def test_ledger_ids_and_verdict_consistency(self):
        response = result()
        objection = {"id": "OBJ-001", "status": "open", "severity": "blocking",
                     "category": "credible_risk", "title": "test", "scenario": "test",
                     "constraint": "test", "evidence": "test", "impact": "test",
                     "falsification_check": "test", "disposition_reason": "test"}
        response["objections"] = [objection]
        with self.assertRaisesRegex(ValueError, "contradicts"):
            judge.validate(response)
        response["verdict"] = "blocked"
        judge.validate(response)
        response["objections"].append(dict(objection))
        with self.assertRaisesRegex(ValueError, "duplicate"):
            judge.validate(response)
        response["objections"] = [{**objection, "status": "fixed"}]
        response["verdict"] = "survived"
        with self.assertRaisesRegex(ValueError, "without a prior ledger"):
            judge.validate(response)
        judge.validate(response, ledger=True)
        response["objections"] = [{**objection, "evidence": "  "}]
        response["verdict"] = "blocked"
        with self.assertRaisesRegex(ValueError, "empty evidence"):
            judge.validate(response)


if __name__ == "__main__":
    unittest.main()
