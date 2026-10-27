"""coderabbit_skip keeps a PR out of the routine's summons, in the digest and again in act.py (#189)."""
import os
import sys
import unittest
from datetime import datetime, timedelta, timezone
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import act  # noqa: E402
import digest  # noqa: E402

REPO = "o/r"
OLD, HEAD = "a" * 40, "b" * 40


def iso(minutes_ago):
    return (datetime.now(timezone.utc) - timedelta(minutes=minutes_ago)).strftime("%Y-%m-%dT%H:%M:%SZ")


def fake_gh(labels, reviewed_at=None):
    """A PR at HEAD; with reviewed_at, CodeRabbit reviewed OLD then, so it is a re-review candidate."""
    reviews = [{"user": {"login": digest.CR}, "body": "Actionable comments posted: 1", "commit_id": OLD, "submitted_at": reviewed_at}] if reviewed_at else []
    routes = {
        f"repos/{REPO}/pulls?state=open&per_page=100": [listed(labels)],
        f"repos/{REPO}/pulls?state=closed&sort=updated&direction=desc&per_page=50&page=1": [],
        f"repos/{REPO}/pulls/7": {"head": {"sha": HEAD}, "changed_files": 1, "labels": [{"name": n} for n in labels]},
        f"repos/{REPO}/commits/{HEAD}": {"commit": {"committer": {"date": iso(30)}}},
        f"repos/{REPO}/pulls/7/files?per_page=100": [{"filename": "src/x.py"}],
        f"repos/{REPO}/pulls/7/reviews?per_page=100": reviews,
        f"repos/{REPO}/issues/7/comments?per_page=100": [],
        f"repos/{REPO}/pulls/7/comments?per_page=100": [],
        f"repos/{REPO}/compare/{OLD}...{HEAD}": {"commits": [{"sha": HEAD, "commit": {"message": "feat: more"}}], "files": []},
    }
    return lambda path, paginate=False: routes[path]


def listed(labels):
    return {
        "number": 7, "title": "t", "created_at": iso(120), "user": {"login": digest.OPERATOR},
        "head": {"ref": "feat/x"}, "draft": False, "labels": [{"name": n} for n in labels],
    }


def facts(labels, reviewed_at=None):
    with mock.patch.object(digest, "gh", fake_gh(labels, reviewed_at)):
        return digest.pr_facts(REPO, listed(labels))


class DigestSkipLabel(unittest.TestCase):
    def test_unlabelled_pr_is_a_candidate(self):
        f = facts([])
        self.assertNotIn("excluded", f)
        self.assertFalse(f["coderabbit_reviewed_head"])

    def test_labelled_initial_review_is_excluded_with_reason(self):
        self.assertEqual(facts([digest.SKIP_LABEL])["excluded"], "label coderabbit_skip")

    def test_labelled_re_review_is_excluded_and_keeps_its_review(self):
        f = facts(["bug", digest.SKIP_LABEL], reviewed_at=iso(10))
        self.assertEqual(f["excluded"], "label coderabbit_skip")
        self.assertIsNotNone(f["coderabbit_last_review_at"])

    def test_labelled_pr_review_still_holds_the_slot(self):
        with mock.patch.object(digest, "REPOS", [REPO]), mock.patch.object(digest, "gh", fake_gh([digest.SKIP_LABEL], iso(10))):
            _, d = digest.build()
        self.assertFalse(d["slot_open"])


class ActRereadsLabels(unittest.TestCase):
    def run_act(self, labels, posted):
        argv = ["act.py", REPO, "7", "@coderabbitai review"]
        with mock.patch.object(act, "DIGEST_PATH", os.path.join(os.path.dirname(__file__), "no-digest.json")), \
                mock.patch.object(act, "gh", lambda path, paginate=False: [{"name": n} for n in labels]), \
                mock.patch.object(act, "request", posted), mock.patch.object(sys, "argv", argv):
            act.main()

    def test_label_added_after_the_digest_stops_the_summon(self):
        self.assertNotIn("excluded", facts([]))
        posted = mock.Mock()
        with self.assertRaises(SystemExit) as e:
            self.run_act([digest.SKIP_LABEL], posted)
        self.assertIn("coderabbit_skip", str(e.exception.code))
        posted.assert_not_called()

    def test_unlabelled_pr_is_summoned_with_the_marker(self):
        posted = mock.Mock(return_value=({"html_url": "u"}, ""))
        self.run_act(["bug"], posted)
        url, payload = posted.call_args.args
        self.assertTrue(url.endswith(f"repos/{REPO}/issues/7/comments"))
        self.assertIn(digest.MARKER, payload["body"])


if __name__ == "__main__":
    unittest.main()
