import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "codex-quota.py"


def check(env, *flags):
    done = subprocess.run([sys.executable, str(SCRIPT), "check", *flags], capture_output=True, text=True,
                          env={**os.environ, **env}, timeout=30)
    return done.returncode, done.stdout.strip()


class CachedQuotaTest(unittest.TestCase):
    def setUp(self):
        self.home = Path(tempfile.mkdtemp())
        self.day = self.home / "sessions/2026/10/10"
        self.day.mkdir(parents=True)

    def rollout(self, used, resets_in, name="rollout-a.jsonl"):
        event = {"timestamp": time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime()), "type": "event_msg",
                 "payload": {"type": "token_count", "rate_limits": {
                     "primary": {"used_percent": used, "window_minutes": 300, "resets_at": int(time.time()) + resets_in},
                     "secondary": {"used_percent": 66.0, "window_minutes": 10080, "resets_at": int(time.time()) + 86400}}}}
        (self.day / name).write_text('{"type":"session_meta"}\n' + json.dumps(event) + "\n")

    def test_full_window_is_exhausted_with_reset(self):
        self.rollout(100.0, 3600)
        code, line = check({"CODEX_HOME": str(self.home)}, "--cached")
        self.assertEqual(code, 1)
        self.assertRegex(line, r"^exhausted until \d{4}-\d\d-\d\dT\d\d:\d\dZ: 5h 100%, weekly 66% \[from the last session log, 0m old\]$")

    def test_window_past_its_reset_reads_zero(self):
        self.rollout(100.0, -60)
        code, line = check({"CODEX_HOME": str(self.home)}, "--cached")
        self.assertEqual(code, 0)
        self.assertTrue(line.startswith("usable: 5h 0%, weekly 66%"))

    def test_no_live_answer_falls_back_to_the_log(self):
        self.rollout(40.0, 3600)
        code, line = check({"CODEX_HOME": str(self.home), "RIG_CODEX_BIN": "/nonexistent/codex"})
        self.assertEqual(code, 0)
        self.assertIn("[from the last session log", line)

    def test_nothing_known_is_unknown(self):
        code, line = check({"CODEX_HOME": str(self.home), "RIG_CODEX_BIN": "/nonexistent/codex"})
        self.assertEqual(code, 2)
        self.assertTrue(line.startswith("unknown: "))


    def test_invalid_timestamp_uses_file_mtime(self):
        for stamp in [12345, "not-a-date"]:
            with self.subTest(stamp=stamp):
                self.rollout(40.0, 3600)
                path = self.day / "rollout-a.jsonl"
                lines = path.read_text().splitlines()
                event = json.loads(lines[1])
                event["timestamp"] = stamp
                path.write_text(lines[0] + "\n" + json.dumps(event) + "\n")
                code, line = check({"CODEX_HOME": str(self.home)}, "--cached")
                self.assertEqual(code, 0)
                self.assertIn("0m old", line)

    def test_malformed_app_server_answer_is_unknown(self):
        for answer in ['5', '{"id":2,"error":"boom"}', '{"id":2,"result":[1]}', '{"id":2,"result":{"rateLimits":"x"}}']:
            with self.subTest(answer=answer):
                fake = self.home / "codex"
                fake.write_text("#!/bin/sh\nread a; read b; read c\necho '" + answer + "'\n")
                fake.chmod(0o755)
                code, line = check({"CODEX_HOME": str(self.home), "RIG_CODEX_BIN": str(fake),
                                    "RIG_CODEX_QUOTA_TIMEOUT": "3"})
                self.assertEqual(code, 2)
                self.assertTrue(line.startswith("unknown: "), line)


if __name__ == "__main__":
    unittest.main()
