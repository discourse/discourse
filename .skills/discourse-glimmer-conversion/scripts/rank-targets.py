#!/usr/bin/env python3
"""Rank the classic components left on origin/main by conversion risk, lowest first.

Reads origin/main through git (no checkout), leaves out files touched by open PRs labeled
`glimmer-conversion`, and lists unreachable components separately: those are deletion
candidates, not easy conversions. The score is a heuristic for ordering batches; every
pick still goes through analyze.sh and the pre-flight plan.

Usage: .skills/discourse-glimmer-conversion/scripts/rank-targets.py [--top N] [--json PATH] [--list]
`--list` prints the classic inventory and stops (SKILL.md Step 0).
Run from the core checkout. `git fetch origin main` first.
"""

import argparse
import collections
import json
import os
import re

from common import Modules, default_export_name, external_dirs, module_key, module_roots, neighborhood, read_blobs, resolve, run, search_matches, tsconfig_paths

REF = "origin/main"
ROOTS = ["frontend/discourse", "plugins"]
# Known not-a-batch-member cases; each needs its own PR or a decision first.
BLOCKED = {
    "frontend/discourse/app/components/anonymous-topic-footer-buttons.gjs": "passes `this` to getTopicFooterButtons, which calls context.get(); needs the plugin API reworked",
    "frontend/discourse/app/components/discourse-root.js": "root element owning event dispatch; glimmerified once and reverted (27408c7e14b)",
    "frontend/discourse/admin/components/edit-category-localizations.gjs": "built by buildCategoryPanel() in edit-category-panel.gjs; convert the factory and every tab built from it together",
    "frontend/discourse/admin/components/edit-category-topic-template.gjs": "built by buildCategoryPanel() in edit-category-panel.gjs; convert the factory and every tab built from it together",
    "frontend/discourse/app/components/avatar-uploader.gjs": "writes uploadedAvatarId/uploadedAvatarTemplate back into callers, three external plugins included; needs @done(upload) and coordinated external updates",
    "frontend/discourse/app/components/second-factor-form.gjs": "secondFactorMethod/Token flow back through four callers, one via LoginModal -> LocalLoginForm; needs callbacks threaded through",
    "plugins/styleguide/assets/javascripts/discourse/components/styleguide-markdown.js": "cooks its own rendered block via innerHTML; needs a markdown arg instead",
    "plugins/chat/assets/javascripts/discourse/components/chat-to-topic-selector.gjs": "topicTitle/categoryId/tags/selection flow back to the archive-channel modal by two-way binding; needs callbacks there",
}
MUTATING_ARGS =r"value|values|checked|selection|tags|content|status|topicTitle|categoryId|postAction|reason|capsLockOn"
HOOKS = ["didInsertElement", "willDestroyElement", "didDestroyElement", "didReceiveAttrs", "didUpdateAttrs",
         "didRender", "willRender", "willUpdate", "willClearRender", "willInsertElement"]
EVENTS = r"click|doubleClick|keyDown|keyUp|keyPress|mouseEnter|mouseLeave|mouseDown|mouseUp|focusIn|focusOut|change|input|submit|dragOver|dragStart|drop|touchStart|touchEnd|scroll|paste"
END = r"([^A-Za-z0-9/_-]|$)"


# what a file refers to: component invocations, imports, string lookups, superclasses
REF_TOKENS = r'<[A-Z][A-Za-z0-9_]*|from "[^"]+"|component:[a-z0-9/_-]+|component "[^"]+"|extends [A-Za-z0-9_]+'


def in_flight():
    out = run(["gh", "pr", "list", "--state", "open", "--label", "glimmer-conversion", "--limit", "200",
               "--json", "files", "--jq", ".[].files[].path"])
    return set(out.split())


def reference_index(tree):
    """Token -> files that contain it, plus module path -> files that import it, from one `git grep`."""
    exists = tree.__contains__
    roots = module_roots("", read_blobs(REF, tsconfig_paths(tree)))
    refs = collections.defaultdict(set)
    importers = collections.defaultdict(set)
    for line in run(["git", "grep", "-I", "-oE", REF_TOKENS, REF, "--", *ROOTS], ok=(0, 1)).splitlines():
        _, path, token = line.split(":", 2)
        if token.startswith("from "):
            if target := resolve(token[6:-1], os.path.dirname(path), roots, exists):
                importers[target].add(path)
        else:
            refs[token].add(path)
    return refs, importers


def resolver_name(path):
    stem = path.rsplit(".", 1)[0]
    return stem.split("/components/", 1)[1] if "/components/" in stem else os.path.basename(stem)


def score(path, src, ext_blob, refs, importers, listdir):
    body, tpl = (src.split("<template>", 1) + [""])[:2]
    n = lambda p, s=body: len(re.findall(p, s))
    cls = default_export_name(src)
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

    sites = (importers[path] | refs[f"component:{res}"] | refs[f'component "{res}"']
             | (refs[f"<{cls}"] if cls else set())) - {path}
    ext_pats = [f'from "[^"]*/{re.escape(base)}(\\.g?[jt]s)?"', f"component:{re.escape(res)}{END}", f'component "{re.escape(res)}"']
    if cls:
        ext_pats.append(f"<{cls}([^A-Za-z0-9]|$)")
    ext = bool(re.search("|".join(ext_pats), ext_blob))
    connector = "/connectors/" in path
    subclasses = len(refs[f"extends {cls}"]) if cls else 0
    lines = len(src.splitlines())

    total = (hooks * 3 + observers * 3 + element * 2 + jquery * 4 + mixins * 5 + wrapper + events * 2
             + computeds + len(two_way) * 4 + subclasses * 6 + (4 if ext else 0)
             + (2 if not tagless and not named_tag else 0) + max(0, len(sites) - 1) + lines // 60)
    return dict(file=path, cls=cls, score=total, lines=lines, sites=len(sites), ext=ext, connector=connector,
                reachable=bool(sites) or ext or connector, hooks=hooks, observers=observers, element=element,
                jquery=jquery, mixins=mixins, events=events, computeds=computeds, subclasses=subclasses,
                two_way=sorted(two_way), field_defaults=sorted(field_defaults),
                wrapper="tagless" if tagless else ("explicit" if named_tag else "implicit div"),
                ts=bool(neighborhood(path, listdir)["reason"]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--top", type=int, default=30)
    ap.add_argument("--json")
    ap.add_argument("--list", action="store_true")
    opts = ap.parse_args()

    tree = run(["git", "ls-tree", "-r", "--name-only", REF, "--", *ROOTS]).split()
    modules = Modules(REF)
    classic = modules.classic(tuple(f"{r}/" for r in ROOTS))
    if not classic:
        raise SystemExit(f"no classic components found on {REF}; the classifier is more likely broken than the job done")
    if opts.list:
        print("\n".join(classic))
        return

    dirs = collections.defaultdict(list)
    for f in tree:
        dirs[os.path.dirname(f)].append(os.path.basename(f))
    skip = in_flight()
    bases = {f: list(modules.bases(module_key(f))) for f in classic}
    select_kit = {f for f in classic if "/select-kit/" in f or any("/select-kit/" in b for b in bases[f])}
    # a subclass converts with its base (SKILL.md Step 0), whose score counts it
    listed = {module_key(f) for f in classic}
    subclasses = {f for f in classic if bases[f] and bases[f][0] in listed}
    candidates = [f for f in classic if f not in select_kit and f not in subclasses and f not in skip]
    refs, importers = reference_index(set(tree))
    ext_blob = "\n".join(search_matches(REF_TOKENS, external_dirs()))
    blobs = read_blobs(REF, candidates)

    rows = [score(f, blobs[f], ext_blob, refs, importers, dirs.__getitem__) for f in candidates]
    dead = [r for r in rows if not r["reachable"]]
    blocked = [r for r in rows if r["file"] in BLOCKED and r["reachable"]]
    ranked = sorted((r for r in rows if r["reachable"] and r["file"] not in BLOCKED), key=lambda r: (r["score"], r["lines"]))

    print(f"{len(classic)} classic on {REF}; {len(classic) - len(candidates)} excluded (in flight, select-kit and its subclasses, subclasses of a listed base)")
    print(f"{len(ranked)} ranked, {len(blocked)} blocked, {len(dead)} unreachable\n")
    for r in dead:
        print(f"  DEAD? {r['file']}  (delete, don't convert; confirm per SKILL.md Step 1)")
    for r in blocked:
        print(f"  BLOCKED {r['file']}: {BLOCKED[r['file']]}")
    print(f"\n{'#':>3} {'sc':>3} {'ln':>4} {'st':>3} {'wrapper':<12} {'flags':<34} file")
    for i, r in enumerate(ranked[: opts.top], 1):
        flags = ["ts"] if r["ts"] else []
        flags += [f"{k}:{r[k]}" for k in ["hooks", "observers", "element", "jquery", "mixins", "events", "computeds", "subclasses"] if r[k]]
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
