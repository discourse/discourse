#!/usr/bin/env python3
"""Refresh the status marks in PROGRESS.md from GitHub: ☑️ merged, ✅ approved, none otherwise.

Merged entries are final and not queried again. Run from anywhere; needs `gh`.
"""

import json
import os
import re
import subprocess

PATH = os.path.join(os.path.dirname(__file__), "..", "PROGRESS.md")
MERGED, APPROVED = "☑️", "✅"
# CLICOLOR_FORCE/FORCE_COLOR in the environment make gh color its JSON even when piped
PLAIN_ENV = {k: v for k, v in os.environ.items() if k not in ("CLICOLOR_FORCE", "FORCE_COLOR")} | {"NO_COLOR": "1"}
ENTRY = re.compile(r"^(- \[#(\d+)\]\([^)]*\))(?: (?:☑️|✅))?(.*)$")


def status(number):
    r = subprocess.run(
        ["gh", "pr", "view", number, "--repo", "discourse/discourse", "--json", "state,reviewDecision"],
        capture_output=True, text=True, env=PLAIN_ENV,
    )
    if r.returncode != 0:
        raise SystemExit(f"gh pr view {number} failed: {r.stderr.strip()}")
    data = json.loads(r.stdout)
    if data["state"] == "MERGED":
        return MERGED
    return APPROVED if data["reviewDecision"] == "APPROVED" else None


lines = open(PATH).read().split("\n")
changed = 0
for i, line in enumerate(lines):
    m = ENTRY.match(line)
    if not m or f" {MERGED}" in line:
        continue
    head, number, rest = m.groups()
    mark = status(number)
    new = f"{head} {mark}{rest}" if mark else f"{head}{rest}"
    if new != line:
        lines[i] = new
        changed += 1
        print(f"#{number}: {mark or 'unmarked'}")

open(PATH, "w").write("\n".join(lines))
print(f"{changed} entries updated")
