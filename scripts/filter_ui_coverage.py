#!/usr/bin/env python3
"""
filter_ui_coverage.py

Reads coverage-uncovered.txt (produced by extract_uncovered_lines.py from the
llvm-cov unit-test pass) and removes any lines that the UI test xcresult shows
as covered.  Writes the filtered result back to coverage-uncovered.txt and
prints a summary.

Usage:
    python3 scripts/filter_ui_coverage.py <xcresult_path> <repo_root>
"""

import os
import re
import subprocess
import sys


def xccov_covered_lines(xcresult: str, abs_path: str) -> set:
    """Return the set of line numbers hit at least once in abs_path by xcresult."""
    try:
        r = subprocess.run(
            ["xcrun", "xccov", "view", "--archive", "--file", abs_path, xcresult],
            capture_output=True,
            text=True,
            timeout=30,
        )
    except Exception:
        return set()
    if r.returncode != 0:
        return set()

    covered = set()
    for line in r.stdout.splitlines():
        # xccov --archive --file format:  "  <lineno>: <count>"  or  "  <lineno>: *"
        # "*" means non-executable; a positive integer means the line was hit.
        m = re.match(r"\s*(\d+):\s*(\d+)", line)
        if m and int(m.group(2)) > 0:
            covered.add(int(m.group(1)))
    return covered


def main() -> None:
    if len(sys.argv) < 3:
        print("Usage: filter_ui_coverage.py <xcresult> <repo_root>", file=sys.stderr)
        sys.exit(1)

    xcresult = sys.argv[1]
    repo_root = sys.argv[2]

    uncovered_path = os.path.join(repo_root, "coverage-uncovered.txt")
    if not os.path.isfile(uncovered_path):
        print("coverage-uncovered.txt not found — nothing to filter.", file=sys.stderr)
        sys.exit(0)

    with open(uncovered_path, encoding="utf-8") as f:
        raw_lines = f.read().splitlines()

    # Parse "Nostos/Views/GalleryView.swift:10,11,42" entries.
    entries: dict[str, set] = {}
    unparseable: list[str] = []
    for raw in raw_lines:
        if not raw.strip():
            continue
        colon = raw.rfind(":")
        if colon == -1:
            unparseable.append(raw)
            continue
        rel, nums_str = raw[:colon], raw[colon + 1:]
        try:
            line_nos = {int(n) for n in nums_str.split(",") if n.strip()}
        except ValueError:
            unparseable.append(raw)
            continue
        entries[rel] = line_nos

    total_removed = 0
    files_changed = 0

    for rel, uncovered_set in list(entries.items()):
        abs_path = os.path.join(repo_root, rel)
        if not os.path.isfile(abs_path):
            continue
        covered = xccov_covered_lines(xcresult, abs_path)
        if not covered:
            continue
        newly_covered = uncovered_set & covered
        if newly_covered:
            entries[rel] = uncovered_set - newly_covered
            total_removed += len(newly_covered)
            files_changed += 1

    # Drop files whose uncovered set is now empty.
    entries = {k: v for k, v in entries.items() if v}

    with open(uncovered_path, "w", encoding="utf-8") as f:
        for rel, line_nos in sorted(entries.items()):
            f.write(f"{rel}:{','.join(str(n) for n in sorted(line_nos))}\n")
        for raw in unparseable:
            f.write(raw + "\n")

    print(
        f"UI coverage filter: {total_removed} line(s) across {files_changed} file(s) "
        "removed from coverage-uncovered.txt (now covered by UI tests)."
    )


if __name__ == "__main__":
    main()
