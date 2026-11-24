"""Tests for CHANGELOG.md and scripts/release_notes.py.

python3 -m unittest discover -s tests
"""

from __future__ import annotations

import re
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import release_notes as rn

CHANGELOG = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
WORKFLOW = (ROOT / ".github" / "workflows" / "build.yml").read_text(encoding="utf-8")


def version_key(v: str) -> tuple[int, ...]:
    return tuple(int(x) for x in v.split("."))


class TestChangelog(unittest.TestCase):
    def test_headings(self):
        heads = [line for line in CHANGELOG.splitlines() if line.startswith("## ")]
        bad = [
            h
            for h in heads
            if not re.match(r"^## \d+\.\d+(\.\d+)? \(\d{4}-\d{2}-\d{2}\)$", h)
        ]
        self.assertEqual(bad, [])

    def test_newest_first_from_first_release(self):
        versions = list(rn.entries(CHANGELOG))
        self.assertEqual(versions, sorted(versions, key=version_key, reverse=True))
        self.assertEqual(versions[-1], "1.0")

    def test_three_part_versions_from_421(self):
        # Two-part versions are history (v4.2 and earlier); new tags are vX.Y.Z.
        late = [v for v in rn.entries(CHANGELOG) if version_key(v) >= (4, 2, 1)]
        self.assertTrue(late)
        self.assertEqual([v for v in late if v.count(".") != 2], [])

    def test_every_entry_is_release_notes(self):
        for version, lines in rn.entries(CHANGELOG).items():
            with self.subTest(version=version):
                lead, changes, _action = rn.parse(lines)
                self.assertTrue(lead)
                self.assertGreaterEqual(len(changes), 1)
                self.assertLessEqual(len(changes), 5)

    def test_readme_links_the_changelog(self):
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("(./CHANGELOG.md)", readme)
        self.assertIn("\n## Downloads\n", readme)  # the footer links #downloads

    def test_no_third_party_app_names(self):
        self.assertNotIn("passwall", CHANGELOG.lower())


class TestReleaseNotes(unittest.TestCase):
    SAMPLE = (
        "# Changelog\n\n"
        "## 9.1.0 (2027-01-02)\n\n"
        "Lead sentence that\nwraps.\n\n"
        "- First change\n  continues here.\n"
        "- Second change.\n\n"
        "Action needed: do not keep\nsettings.\n\n"
        "## 9.0 (2027-01-01)\n\nOld.\n\n- Old change.\n"
    )

    def test_entry_becomes_notes(self):
        notes, found = rn.notes_for_tag("v9.1.0", self.SAMPLE)
        self.assertTrue(found)
        self.assertTrue(
            notes.startswith(
                "Lead sentence that wraps.\n\n### Changes\n"
                "- First change continues here.\n- Second change.\n\n"
                "### Action needed\n- Do not keep settings.\n\n"
            )
        )
        self.assertTrue(notes.endswith(rn.FOOTER))
        self.assertIn("#downloads", rn.FOOTER)
        self.assertIn("Part of the Nova infrastructure toolkit.", rn.FOOTER)

    def test_two_part_tag(self):
        notes, found = rn.notes_for_tag("v9.0", self.SAMPLE)
        self.assertTrue(found)
        self.assertTrue(notes.startswith("Old.\n\n### Changes\n- Old change.\n"))

    def test_missing_entry_gets_placeholder(self):
        notes, found = rn.notes_for_tag("v9.9.9", self.SAMPLE)
        self.assertFalse(found)
        self.assertTrue(notes.startswith("HarryWrt v9.9.9.\n\n"))

    def test_known_issues(self):
        notes = rn.render("Lead.", ["A."], [], "Known issues (fixed in 9.1.0)", ["B."])
        self.assertIn("### Known issues (fixed in 9.1.0)\n- B.\n", notes)

    def test_cli(self):
        out = subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "release_notes.py"), "v4.2.1"],
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertIn("### Changes", out.stdout)
        self.assertEqual(out.stderr, "")


class TestWorkflow(unittest.TestCase):
    def test_release_notes_come_from_the_changelog(self):
        self.assertIn('scripts/release_notes.py" "${TAG}"', WORKFLOW)
        self.assertNotIn("RELEASE_TEMPLATE", WORKFLOW)
        self.assertFalse((ROOT / ".github" / "RELEASE_TEMPLATE.md").exists())

    def test_release_title(self):
        self.assertIn('--title "${REL} — OpenWrt ${OWRT}"', WORKFLOW)

    def test_only_tags_build_firmware(self):
        # Pushing a branch must never start a firmware build.
        on = WORKFLOW.split("\non:\n", 1)[1].split("\npermissions:", 1)[0]
        self.assertIn('tags:\n      - "v*"', on)
        self.assertNotIn("branches", on)


if __name__ == "__main__":
    unittest.main()
