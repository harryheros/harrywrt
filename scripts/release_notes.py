#!/usr/bin/env python3
"""Release notes for a HarryWrt tag, taken from CHANGELOG.md.

    python3 scripts/release_notes.py v4.2.1 > release_notes.md

A CHANGELOG entry is

    ## 4.2.1 (2026-11-16)

    One-paragraph lead.

    - A change (continuation lines are indented).
    - Another change.

    Action needed: optional paragraph.

and becomes the lead, a "Changes" list, an optional "Action needed" list and
the fixed footer below. A tag without an entry gets a short placeholder and a
warning annotation, so a missing entry never blocks publishing the firmware.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO_URL = "https://github.com/harryheros/harrywrt"

FOOTER = (
    f"Which file to download: see the [README]({REPO_URL}#downloads). "
    "Check a download with `sha256sum -c --ignore-missing SHA256SUMS`.\n"
    "\n"
    f"See the full [changelog]({REPO_URL}/blob/main/CHANGELOG.md) for details.\n"
    "\n"
    "Part of the Nova infrastructure toolkit.\n"
)

HEADING = re.compile(r"^## (\S+) \((\d{4}-\d{2}-\d{2})\)$")


def entries(text: str) -> dict[str, list[str]]:
    """Version -> the entry's lines (without the heading)."""
    out: dict[str, list[str]] = {}
    current = None
    for line in text.splitlines():
        if line.startswith("## "):
            m = HEADING.match(line)
            current = m.group(1) if m else None
            if current:
                out[current] = []
        elif current:
            out[current].append(line)
    return out


def parse(lines: list[str]) -> tuple[str, list[str], list[str]]:
    """Entry lines -> (lead, changes, action_needed)."""
    paragraphs, block = [], []
    for line in lines + [""]:
        if line.strip():
            block.append(line)
        elif block:
            paragraphs.append(block)
            block = []
    lead, changes, action = "", [], []
    for para in paragraphs:
        if para[0].startswith("- "):
            for line in para:
                if line.startswith("- "):
                    changes.append(line[2:].strip())
                else:
                    changes[-1] += " " + line.strip()
        elif para[0].startswith("Action needed:"):
            text = " ".join(x.strip() for x in para)[len("Action needed:") :].strip()
            action.append(text[:1].upper() + text[1:])
        elif not lead:
            lead = " ".join(x.strip() for x in para)
        else:
            raise ValueError(f"unexpected paragraph in CHANGELOG entry: {para[0]!r}")
    return lead, changes, action


def render(
    lead: str,
    changes: list[str],
    action: list[str] = (),
    known_heading: str | None = None,
    known: list[str] = (),
) -> str:
    out = [lead, "", "### Changes"] + [f"- {c}" for c in changes]
    if action:
        out += ["", "### Action needed"] + [f"- {a}" for a in action]
    if known:
        out += ["", f"### {known_heading}"] + [f"- {k}" for k in known]
    return "\n".join(out) + "\n\n" + FOOTER


def notes_for_tag(tag: str, changelog: str) -> tuple[str, bool]:
    """(notes, found): the notes for a tag such as v4.2.1."""
    version = tag.removeprefix("v")
    lines = entries(changelog).get(version)
    if lines is None:
        return f"HarryWrt {tag}.\n\n" + FOOTER, False
    return render(*parse(lines)), True


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: release_notes.py TAG", file=sys.stderr)
        return 2
    tag = argv[1]
    notes, found = notes_for_tag(
        tag, (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    )
    if not found:
        print(
            f"::warning::CHANGELOG.md has no entry for {tag}; the release gets placeholder notes",
            file=sys.stderr,
        )
    sys.stdout.write(notes)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
