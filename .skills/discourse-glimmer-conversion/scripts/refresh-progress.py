#!/usr/bin/env python3
"""Refresh the status marks in PROGRESS.md from GitHub: ☑️ merged, ✅ approved, none otherwise.

Merged entries are final and not queried again. Run from anywhere; needs `gh`.
"""

import json
import os
import re

from common import run

PATH = os.path.join(os.path.dirname(__file__), "..", "PROGRESS.md")
MERGED, APPROVED = "☑️", "✅"
ENTRY = re.compile(r"^(- \[#(\d+)\]\([^)]*\))(?: (?:☑️|✅))?(.*)$")
REPO = ["--repo", "discourse/discourse"]

# one call for every labeled PR; an unlabeled entry falls back to its own lookup
labeled = {str(pr["number"]): pr for pr in json.loads(run(
    ["gh", "pr", "list", *REPO, "--state", "all", "--label", "glimmer-conversion", "--limit", "500",
     "--json", "number,state,reviewDecision"]))}


def status(number):
    pr = labeled.get(number) or json.loads(run(["gh", "pr", "view", number, *REPO, "--json", "state,reviewDecision"]))
    if pr["state"] == "MERGED":
        return MERGED
    return APPROVED if pr["reviewDecision"] == "APPROVED" else None


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
