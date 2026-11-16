#!/usr/bin/env python3
"""The "file type" section of analyze.sh: the evidence for SKILL.md Step 1's .gjs/.gts rule.

Usage: file-type.py CORE_DIR COMPONENT REL < call-site lines (path:line:text, as analyze.sh prints them)
REL is the component's path relative to its repo, without the extension (analyze.sh's $rel).
Paths in the call-site lines are relative to CORE_DIR.
"""

import glob
import os
import re
import sys

from common import module_roots, neighborhood, resolve

core, target, rel = sys.argv[1], sys.argv[2], sys.argv[3]
stem = target.rsplit(".", 1)[0]
repo = stem[: -len(rel)].rstrip("/") if stem.endswith(rel) else os.path.dirname(target)
here = os.path.dirname(target)
configs = {os.path.relpath(p, core): open(p).read()
           for p in [os.path.join(core, "frontend/discourse/tsconfig.json"), *glob.glob(os.path.join(core, "plugins/*/tsconfig.json"))]
           if os.path.isfile(p)}
roots = module_roots(core, configs)


def find(spec, importer_dir):
    return resolve(spec, importer_dir, roots, os.path.isfile, prefix=core)


def shown(path):
    return os.path.relpath(path, core) if path.startswith(core + "/") else path


def listdir(d):
    full = os.path.join(repo, d)
    return [n for n in os.listdir(full) if os.path.isfile(os.path.join(full, n))] if os.path.isdir(full) else []


facts = neighborhood(rel, listdir)
base = os.path.basename(rel).rsplit(".", 1)[0]
if facts["reason"] == "ui-kit rule":
    print("  ui-kit: new and reworked primitives are TypeScript with a Signature, TSDoc and a type test")
    print("    (docs/developer-guides/docs/03-code-internals/02-ui-kit.md)")
    test = os.path.join(core, "frontend/discourse/type-tests/ui-kit", f"{base}-test.gts")
    print(f"    type test: {shown(test)}" + (" (exists)" if os.path.isfile(test) else " (add it)"))
print("  directory: " + "  ".join(f".{e}={n}" for e, n in facts["counts"].items()))
if facts["family"]:
    print(f"  family ({facts['family_prefix']}*, {base}/): " + ", ".join(facts["family"]))

# Helpers resolve in templates without a cast; components rendered from a .gts file need types.
untyped = []
for name, spec in re.findall(r'^import ([A-Z][A-Za-z0-9_]*)(?:,\s*\{[^}]*\})? from "([^"]+)"', open(target).read(), re.M):
    hit = find(spec, here)
    if hit and hit.endswith((".gjs", ".js")) and re.search(r"/(components|ui-kit|select-kit|float-kit|form-kit)/", hit):
        untyped.append(f"{name} ({shown(hit)})")
if untyped:
    print("  renders untyped components (each needs a cast in a .gts file): " + ", ".join(untyped))

# Relative imports carry an extension, so a .gjs -> .gts rename must update each of these.
importers = []
for line in sys.stdin:
    path, _, rest = line.rstrip("\n").partition(":")
    lineno, _, text = rest.partition(":")
    path = os.path.join(core, path)
    m = re.search(r'from "([^"]+\.g?[jt]s)"', text)
    if m and find(m.group(1), os.path.dirname(path)) == target:
        importers.append(f"{shown(path)}:{lineno}")
if importers:
    print("  imports with an extension (update them on a .gts rename): " + ", ".join(importers))

if facts["reason"]:
    print(f"  -> .gts ({facts['reason']})")
    if len(untyped) >= 3:
        print("     several untyped components: apply the TypeScript skill's scope triage first")
else:
    print("  -> .gjs (the neighborhood is JavaScript)")
