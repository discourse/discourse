#!/usr/bin/env python3
"""Rank the classic components left on origin/main by conversion risk, lowest first.

Reads origin/main through git (no checkout), leaves out files touched by open PRs labeled
`glimmer-conversion`, and lists unreachable components separately: those are deletion
candidates, not easy conversions. The score is a heuristic for ordering batches; every
pick still goes through analyze.sh and the pre-flight plan.

Usage: .skills/discourse-glimmer-conversion/scripts/rank-targets.py [--top N] [--json PATH]
Run from the core checkout. `git fetch origin main` first.
"""

import argparse
import json
import os
import re
import subprocess

REF = "origin/main"
ROOTS = ["frontend/discourse", "plugins"]
INFRA = {
    "frontend/discourse/app/lib/ember-events.js",
    "frontend/discourse/app/lib/implicit-injections.js",
    "frontend/discourse/app/instance-initializers/component-templates.js",
    "frontend/discourse/app/ui-kit/helpers/d-element.gts",
}
# Known not-a-batch-member cases; each needs its own PR or a decision first.
BLOCKED = {
    "frontend/discourse/app/components/anonymous-topic-footer-buttons.gjs": "passes `this` to getTopicFooterButtons, which calls context.get(); needs the plugin API reworked",
    "frontend/discourse/app/components/discourse-root.js": "root element owning event dispatch; glimmerified once and reverted (27408c7e14b)",
    "frontend/discourse/app/components/reviewable-field-editor.gjs": "passes @value into DEditor, which sets it; needs a data-flow redesign",
    "frontend/discourse/admin/components/site-settings/url-list.gjs": "passes @values into ValueList, which sets it and hands back an array for a string setting",
}
EXTERNAL = [
    "all-the-plugins/official", "all-the-plugins/third-party",
    "all-the-themes/official", "all-the-themes/third-party",
    "all-the-custom-plugins/plugins", "all-the-custom-themes/themes",
]
MUTATING_ARGS = r"value|values|checked|selection|tags|content|status|topicTitle|categoryId|postAction|reason|capsLockOn"
HOOKS = ["didInsertElement", "willDestroyElement", "didDestroyElement", "didReceiveAttrs", "didUpdateAttrs",
         "didRender", "willRender", "willUpdate", "willClearRender", "willInsertElement"]
EVENTS = r"click|doubleClick|keyDown|keyUp|keyPress|mouseEnter|mouseLeave|mouseDown|mouseUp|focusIn|focusOut|change|input|submit|dragOver|dragStart|drop|touchStart|touchEnd|scroll|paste"
END = r"([^A-Za-z0-9/_-]|$)"


def run(args, ok=(0,)):
    r = subprocess.run(args, capture_output=True, text=True)
    # git grep exits 1 on "no match"; anything else is a broken command, not an empty result
    if r.returncode not in ok:
        raise SystemExit(f"command failed ({r.returncode}): {' '.join(args)}\n{r.stderr[:400]}")
    return r.stdout


def in_flight():
    out = run(["gh", "pr", "list", "--state", "open", "--label", "glimmer-conversion",
               "--limit", "200", "--json", "number", "--jq", ".[].number"])
    files = set()
    for num in out.split():
        files.update(run(["gh", "pr", "diff", num, "--name-only"]).split())
    return files


def external_blob():
    base = os.path.expanduser("~/discourse/all-the")
    dirs = [os.path.join(base, d) for d in EXTERNAL if os.path.isdir(os.path.join(base, d))]
    if not dirs:
        return ""
    return run(["grep", "-rhoE", r'<[A-Z][A-Za-z0-9]*|from "[^"]+"|component:[a-z0-9/_-]+',
                *dirs, "--exclude-dir=node_modules", "--exclude-dir=.git"], ok=(0, 1))


def git_grep_files(pattern):
    return run(["git", "grep", "-lE", pattern, REF, "--", *ROOTS], ok=(0, 1)).split()


def resolver_name(path):
    stem = path.rsplit(".", 1)[0]
    ip = stem.replace("frontend/discourse/app/", "discourse/").replace("frontend/discourse/admin/", "discourse/admin/")
    ip = re.sub(r"plugins/([^/]+)/(?:admin/)?assets/javascripts/", r"discourse/plugins/\1/", ip)
    return ip.split("/components/", 1)[1] if "/components/" in ip else os.path.basename(stem)


def score(path, src, ext_blob):
    body, tpl = (src.split("<template>", 1) + [""])[:2]
    n = lambda p, s=body: len(re.findall(p, s))
    cls = (re.search(r"export default class (\w+)", src) or [None, None])[1]
    base = os.path.basename(path.rsplit(".", 1)[0])
    res = resolver_name(path)

    hooks = sum(n(rf"\b{h}\b") for h in HOOKS)
    observers = n(r"@observes\(") + n(r"@on\(")
    element = n(r"this\.element\b") + n(r"this\.\$\(")
    jquery = 1 if re.search(r'from "jquery"|\bjQuery\b', body) else 0
    mixins = n(r"\.extend\(") + n(r"\bMixin\b")
    events = len(re.findall(rf"^\s{{2}}({EVENTS})\(", body, re.M))
    computeds = n(r"@computed\(")
    wrapper = n(r"@classNameBindings\(") * 2 + n(r"@attributeBindings\(") * 2 + n(r"@classNames\(")
    tagless = bool(re.search(r'@tagName\(""\)', body))
    named_tag = bool(re.search(r'@tagName\("[^"]+"\)', body))
    wrapper += 1 if named_tag else 0

    declared = set(re.findall(r"^ {2}(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?(?:get\s+|set\s+|async\s+)?(\w+)\s*(?:=[^=]|\(|;)", body, re.M))
    written = (set(re.findall(r'this\.set\("(\w+)"', body)) | set(re.findall(r'set\(this, "(\w+)"', body))
               | set(re.findall(r"^\s+this\.(\w+)\s*=[^=]", body, re.M)) | set(re.findall(r'this\.toggleProperty\("(\w+)"', body)))
    two_way = {w for w in written - declared if w not in {"element", "elementId"}}
    two_way |= {m for m in re.findall(r"\(mut this\.(\w+)", tpl) if m not in declared}
    two_way |= {m for m in re.findall(rf"@(?:{MUTATING_ARGS})=\{{\{{this\.(\w+)\}}\}}", tpl) if m not in declared}
    # a class field callers may also pass: an override at best, a shared two-way flag at worst
    field_defaults = {m for m in re.findall(r"^ {2}(\w+)\s*=\s*[^=]", body, re.M)}

    pats = [f'from "[^"]*/{re.escape(base)}"', f"component:{re.escape(res)}{END}", f'component "{re.escape(res)}"']
    if cls:
        pats.append(f"<{cls}([^A-Za-z0-9]|$)")
    pat = "|".join(pats)
    sites = [f.split(":", 1)[1] for f in git_grep_files(pat) if f.split(":", 1)[1] != path]
    ext = bool(re.search(pat, ext_blob))
    connector = "/connectors/" in path
    subclasses = len(git_grep_files(f"extends {cls}([^A-Za-z0-9]|$)")) if cls else 0
    lines = len(src.splitlines())

    total = (hooks * 3 + observers * 3 + element * 2 + jquery * 4 + mixins * 5 + wrapper + events * 2
             + computeds + len(two_way) * 4 + subclasses * 6 + (4 if ext else 0)
             + (2 if not tagless and not named_tag else 0) + max(0, len(sites) - 1) + lines // 60)
    return dict(file=path, cls=cls, score=total, lines=lines, sites=len(sites), ext=ext, connector=connector,
                reachable=bool(sites) or ext or connector, hooks=hooks, observers=observers, element=element,
                jquery=jquery, mixins=mixins, events=events, computeds=computeds, subclasses=subclasses,
                two_way=sorted(two_way), field_defaults=sorted(field_defaults),
                wrapper="tagless" if tagless else ("explicit" if named_tag else "implicit div"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--top", type=int, default=30)
    ap.add_argument("--json")
    opts = ap.parse_args()

    classic = [f.split(":", 1)[1] for f in git_grep_files(r'^import Component from "@ember/component"')]
    classic = [f for f in classic if re.search(r"\.(js|gjs)$", f) and not re.search(r"node_modules|/dist/|/tests?/", f)]
    skip = in_flight()
    candidates = [f for f in classic if f not in INFRA and "/select-kit/" not in f and f not in skip]
    ext_blob = external_blob()

    rows = [score(f, run(["git", "show", f"{REF}:{f}"]), ext_blob) for f in candidates]
    dead = [r for r in rows if not r["reachable"]]
    blocked = [r for r in rows if r["file"] in BLOCKED and r["reachable"]]
    ranked = sorted((r for r in rows if r["reachable"] and r["file"] not in BLOCKED), key=lambda r: (r["score"], r["lines"]))

    print(f"{len(classic)} classic on {REF}; {len(classic) - len(candidates)} excluded (in flight, select-kit, infra)")
    print(f"{len(ranked)} ranked, {len(blocked)} blocked, {len(dead)} unreachable\n")
    for r in dead:
        print(f"  DEAD? {r['file']}  (delete, don't convert; confirm per SKILL.md Step 1)")
    for r in blocked:
        print(f"  BLOCKED {r['file']}: {BLOCKED[r['file']]}")
    print(f"\n{'#':>3} {'sc':>3} {'ln':>4} {'st':>3} {'wrapper':<12} {'flags':<34} file")
    for i, r in enumerate(ranked[: opts.top], 1):
        flags = [f"{k}:{r[k]}" for k in ["hooks", "observers", "element", "jquery", "mixins", "events", "computeds", "subclasses"] if r[k]]
        if r["ext"]:
            flags.append("ext")
        if r["two_way"]:
            flags.append("2way:" + ",".join(r["two_way"][:2]))
        if r["field_defaults"]:
            flags.append("fields:" + ",".join(r["field_defaults"][:2]))
        short = r["file"].replace("frontend/discourse/", "").replace("assets/javascripts/discourse/", "")
        print(f"{i:>3} {r['score']:>3} {r['lines']:>4} {r['sites']:>3} {r['wrapper']:<12} {', '.join(flags)[:34]:<34} {short}")

    if opts.json:
        with open(opts.json, "w") as fh:
            json.dump(dict(ranked=ranked, blocked=blocked, dead=dead), fh, indent=1)


if __name__ == "__main__":
    main()
