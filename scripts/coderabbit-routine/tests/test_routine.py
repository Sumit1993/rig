"""coderabbit_skip keeps a PR out of the routine's summons, in the digest and again in act.py (#189); act.py rechecks the head and the digest's age before posting."""
import os
import json
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import act  # noqa: E402
import digest  # noqa: E402

REPO = "o/r"
OLD, HEAD, BASE_COMMIT = "a" * 40, "b" * 40, "c" * 40


def iso(minutes_ago):
    return (datetime.now(timezone.utc) - timedelta(minutes=minutes_ago)).strftime("%Y-%m-%dT%H:%M:%SZ")


def fake_gh(labels, reviewed_at=None, base="main"):
    """A PR at HEAD; with reviewed_at, CodeRabbit reviewed OLD then, so it is a re-review candidate."""
    reviews = [{"user": {"login": digest.CR}, "body": "Actionable comments posted: 1", "commit_id": OLD, "submitted_at": reviewed_at}] if reviewed_at else []
    routes = {
        f"repos/{REPO}/pulls?state=open&per_page=100": [listed(labels)],
        f"repos/{REPO}/pulls?state=closed&sort=updated&direction=desc&per_page=50&page=1": [],
        f"repos/{REPO}/pulls/7": {"head": {"sha": HEAD}, "base": {"ref": base, "repo": {"default_branch": "main"}}, "changed_files": 1, "labels": [{"name": n} for n in labels]},
        f"repos/{REPO}/commits/{HEAD}": {"commit": {"committer": {"date": iso(30)}}},
        f"repos/{REPO}/pulls/7/files?per_page=100": [{"filename": "src/x.py"}],
        f"repos/{REPO}/pulls/7/reviews?per_page=100": reviews,
        f"repos/{REPO}/issues/7/comments?per_page=100": [],
        f"repos/{REPO}/pulls/7/comments?per_page=100": [],
        f"repos/{REPO}/compare/{OLD}...{HEAD}": {
            "commits": [{"sha": BASE_COMMIT, "commit": {"message": "feat(base): landed on main"}}, {"sha": HEAD, "commit": {"message": "Merge main into feat/x"}}],
            "files": [{"filename": "src/x.py", "additions": 1, "deletions": 0}, {"filename": "src/main_only.py", "additions": 9, "deletions": 0}],
        },
        f"repos/{REPO}/compare/{base}...{HEAD}": {"commits": [{"sha": HEAD, "commit": {"message": "Merge main into feat/x"}}]},
    }
    return lambda path, paginate=False: routes[path]


def listed(labels):
    return {
        "number": 7, "title": "t", "created_at": iso(120), "user": {"login": digest.OPERATOR},
        "head": {"ref": "feat/x"}, "draft": False, "labels": [{"name": n} for n in labels],
    }


def facts(labels, reviewed_at=None, base="main"):
    with mock.patch.object(digest, "gh", fake_gh(labels, reviewed_at, base)):
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


class DigestSinceReview(unittest.TestCase):
    """Commits a base merge brings in are the base's work, so they never read as new behaviour on the PR."""

    def test_base_commits_are_counted_apart_and_their_files_dropped(self):
        since = facts([], reviewed_at=iso(10))["since_coderabbit_review"]
        self.assertEqual(since["commits"], [{"sha": HEAD[:7], "headline": "Merge main into feat/x"}])
        self.assertEqual(since["from_base"], 1)
        self.assertEqual(since["files"], ["src/x.py +1 -0"])


class DigestStack(unittest.TestCase):
    """A PR stacked on another branch waits for its base to merge (#212)."""

    def test_pr_on_the_default_branch_is_not_stacked(self):
        self.assertIsNone(facts([])["stacked_on"])

    def test_pr_on_another_branch_names_its_base(self):
        self.assertEqual(facts([], base="feat/base")["stacked_on"], "feat/base")


class ActRechecksBeforePosting(unittest.TestCase):
    def run_act(self, labels, posted, head=HEAD, digest_age=1, write_digest=True):
        argv = ["act.py", REPO, "7", "@coderabbitai review"]
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "digest.json")
            if write_digest:
                with open(path, "w") as f:
                    json.dump({"now": iso(digest_age), "slot_opens_at": None,
                               "repos": {REPO: {"pull_requests": [{"number": 7, "head": HEAD}]}}}, f)
            live = {"head": {"sha": head}, "labels": [{"name": n} for n in labels]}
            with mock.patch.object(act, "DIGEST_PATH", path),                     mock.patch.object(act, "gh", lambda path, paginate=False: live),                     mock.patch.object(act, "request", posted), mock.patch.object(sys, "argv", argv):
                act.main()

    def refused(self, needle, **kw):
        posted = mock.Mock()
        with self.assertRaises(SystemExit) as e:
            self.run_act(kw.pop("labels", []), posted, **kw)
        self.assertIn(needle, str(e.exception.code))
        posted.assert_not_called()

    def test_label_added_after_the_digest_stops_the_summon(self):
        self.assertNotIn("excluded", facts([]))
        self.refused("coderabbit_skip", labels=[digest.SKIP_LABEL])

    def test_head_moved_since_the_digest_stops_the_summon(self):
        self.refused("head moved", head=OLD)

    def test_stale_digest_stops_the_summon(self):
        self.refused("older than", digest_age=act.FRESH_MIN + 5)

    def test_missing_digest_stops_the_summon(self):
        self.refused("no readable digest", write_digest=False)

    def test_unlabelled_pr_is_summoned_with_the_marker(self):
        posted = mock.Mock(return_value=({"html_url": "u"}, ""))
        self.run_act(["bug"], posted)
        url, payload = posted.call_args.args
        self.assertTrue(url.endswith(f"repos/{REPO}/issues/7/comments"))
        self.assertIn(digest.MARKER, payload["body"])


class DigestDrafts(unittest.TestCase):
    def test_draft_is_a_candidate_marked_draft(self):
        with mock.patch.object(digest, "gh", fake_gh([])):
            f = digest.pr_facts(REPO, dict(listed([]), draft=True))
        self.assertNotIn("excluded", f)
        self.assertTrue(f["draft"])


if __name__ == "__main__":
    unittest.main()
