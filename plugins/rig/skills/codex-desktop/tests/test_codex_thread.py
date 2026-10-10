import importlib.util
import sys
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("codex_thread", Path(__file__).resolve().parents[1] / "codex_thread.py")
codex_thread = importlib.util.module_from_spec(spec)
spec.loader.exec_module(codex_thread)


class CodexThreadTests(unittest.TestCase):
    def test_new_thread_persists_and_mounts(self):
        captured = {}

        def fake_rpc(calls, exe=None):
            results = [{}, {"thread": {"id": "t-1"}}]
            captured["calls"] = [(m, p(results) if callable(p) else p) for m, p in calls]
            return results

        opened = []
        with patch.object(codex_thread, "rpc", fake_rpc):
            tid = codex_thread.new_thread("QA pass", "C:\\lane", opener=lambda argv, **kw: opened.append(argv))
        self.assertEqual(tid, "t-1")
        methods = [m for m, _ in captured["calls"]]
        self.assertEqual(methods, ["thread/start", "thread/name/set", "thread/inject_items"])
        start = captured["calls"][0][1]
        self.assertEqual((start["cwd"], start["approvalsReviewer"]), ("C:\\lane", "auto_review"))
        self.assertEqual(captured["calls"][1][1], {"threadId": "t-1", "name": "QA pass"})
        self.assertIn("Start-Process 'codex://threads/t-1'", opened[0][-1])

    def test_queue_uses_argv_not_shell(self):
        with patch.object(codex_thread.subprocess, "run") as run:
            codex_thread.queue("t-1", "do 'it'; rm -rf /", exe="codex.exe")
        argv = run.call_args.args[0]
        self.assertEqual(argv, ["codex.exe", "queue", "--thread", "t-1", "--approve-for-me", "--message", "do 'it'; rm -rf /"])

    def test_rpc_kills_a_silent_server(self):
        real_popen = codex_thread.subprocess.Popen
        silent = lambda argv, **kw: real_popen([sys.executable, "-c", "import time; time.sleep(30)"], **kw)
        with patch.object(codex_thread.subprocess, "Popen", silent):
            with self.assertRaisesRegex(RuntimeError, "deadline"):
                codex_thread.rpc([], exe="codex.exe", deadline=0.5)


if __name__ == "__main__":
    unittest.main()
