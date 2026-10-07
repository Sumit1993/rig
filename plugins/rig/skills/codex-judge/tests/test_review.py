import argparse
import contextlib
import io
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
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
        self.out = self.history / "round-1"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        fake = self.bin / "codex"
        fake.write_text('''#!/usr/bin/env python3
import json, os, pathlib, subprocess, sys, time
args=sys.argv[1:]
required=['--no-daemon','--search','--ask-for-approval','never','exec','--ignore-user-config','--ephemeral','read-only','gpt-6.1-sol','model_reasoning_effort=high','--json']
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
                             run_dir=self.out, effort="high", timeout=timeout))

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

    def test_quota_has_no_fallback_or_valid_result(self):
        os.environ["REVIEW_MODE"] = "quota"
        self.assertEqual(self.run_review(), 1)
        self.assertEqual(self.status()["exit_code"], 9)
        self.assertFalse((self.out / "result.json").exists())

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
        judge.validate(response)


if __name__ == "__main__":
    unittest.main()
