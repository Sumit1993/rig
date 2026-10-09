import base64
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import parse_qs, urlparse

spec = importlib.util.spec_from_file_location("handoff", Path(__file__).resolve().parents[1] / "handoff.py")
handoff = importlib.util.module_from_spec(spec)
spec.loader.exec_module(handoff)


class HandoffTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.packet = self.root / "proposal.md"
        self.packet.write_text("Observe only; do not submit.\n")
        self.directory = self.root / "request"

    def test_native_workspace_required(self):
        with self.assertRaisesRegex(ValueError, "mounted Windows"):
            handoff.prepare(self.packet, self.directory)

    def test_prepares_only_and_never_overwrites(self):
        with patch.object(handoff.subprocess, "check_output", return_value="C:\\Tests\\request\n"):
            with patch.object(Path, "resolve", lambda p, **kw: p):
                original = self.directory
                self.directory = Path("/mnt") / original.relative_to("/")
                packet = b"# Settings dialog review\r\nObserve only; do not submit.\r\n"
                self.packet.write_bytes(packet)
                with patch.object(Path, "mkdir"), patch.object(Path, "write_bytes") as copy, \
                     patch.object(Path, "write_text") as write:
                    status = handoff.prepare(self.packet, self.directory)
                copy.assert_called_once_with(packet)
                self.assertEqual(status["packet_sha256"], handoff.hashlib.sha256(packet).hexdigest())
                self.assertEqual(status["state"], "prepared")
                self.assertFalse(status["execution_verified"])
                links = [c.args[0] for c in write.call_args_list if c.args[0].startswith("codex://")]
                query = parse_qs(urlparse(links[0]).query)
                self.assertEqual(query["path"], ["C:\\Tests\\request"])
                self.assertIn("@Computer", query["prompt"][0])
                self.assertIn('"Settings dialog review"', query["prompt"][0])
                self.assertIn("C:\\Tests\\request", query["prompt"][0])
                self.assertIn("MD5", query["prompt"][0])
                self.assertEqual(status["title"], "Settings dialog review")
                self.assertNotIn("Observe only", links[0])
        with patch.object(Path, "resolve", lambda p, **kw: p), \
             patch.object(handoff.subprocess, "check_output", return_value="\\\\wsl$\\Ubuntu\n"):
            with self.assertRaisesRegex(ValueError, "native drive"):
                handoff.prepare(self.packet, Path("/mnt/request"))

    def test_existing_directory_cannot_be_overwritten(self):
        with patch.object(Path, "resolve", lambda p, **kw: p), \
             patch.object(handoff.subprocess, "check_output", return_value="C:\\Tests\\request\n"), \
             patch.object(Path, "mkdir", side_effect=FileExistsError), \
             patch.object(Path, "write_text") as write:
            with self.assertRaises(FileExistsError):
                handoff.prepare(self.packet, Path("/mnt/request"))
            write.assert_not_called()

    def test_open_failure_preserves_failure_evidence(self):
        with patch.object(Path, "resolve", lambda p, **kw: p), \
             patch.object(handoff.subprocess, "check_output", return_value="C:\\Tests\\request\n"), \
             patch.object(Path, "mkdir"), patch.object(Path, "write_bytes"), patch.object(Path, "write_text") as write, \
             patch.object(handoff.subprocess, "run", side_effect=OSError("launcher unavailable")):
            with self.assertRaises(OSError):
                handoff.prepare(self.packet, Path("/mnt/request"), True)
        self.assertIn('"state": "open_failed"', write.call_args.args[0])
        self.assertIn('"execution_verified": false', write.call_args.args[0])

    def test_open_uses_encoded_argument_not_shell(self):
        with patch.object(Path, "resolve", lambda p, **kw: p), \
             patch.object(handoff.subprocess, "check_output", return_value="C:\\Tests\\request\n"), \
             patch.object(Path, "mkdir"), patch.object(Path, "write_bytes"), patch.object(Path, "write_text"), \
             patch.object(handoff.subprocess, "run") as run:
            status = handoff.prepare(self.packet, Path("/mnt/request"), True)
        self.assertEqual(status["title"], "proposal")
        argv = run.call_args.args[0]
        self.assertEqual(argv[:3], ["powershell.exe", "-NoProfile", "-NonInteractive"])
        script = base64.b64decode(argv[-1]).decode("utf-16le")
        self.assertTrue(script.startswith("Start-Process -FilePath 'codex://new?"))
        self.assertEqual(status["state"], "open_requested")
        self.assertFalse(status["execution_verified"])


if __name__ == "__main__":
    unittest.main()
