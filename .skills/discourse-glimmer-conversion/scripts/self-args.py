#!/usr/bin/env python3
"""List template `@name` reads that match a member of the same Glimmer class.

A blanket `this.` -> `@` rewrite can turn a method reference into an arg nobody passes.
Legitimate reads can also match a member, such as a getter providing an arg default.

Usage: .skills/discourse-glimmer-conversion/scripts/self-args.py [files...]
With no files, looks for Glimmer imports in .gjs and .gts files in core and bundled plugins.
Checks default-exported classes with an inline template that directly extend a Glimmer import.
"""

import re
import sys

from common import parse_imports, run

GLIMMER_DEFAULT = ("@glimmer/component", "default")
CLASS = re.compile(
    r"export\s+default\s+class\s+(?P<name>\w+)(?:<[^>]*>)?\s+extends\s+"
    r"(?P<base>\w+)(?:<.*?>)?\s*\{(?P<body>.*?)\n  <template>(?P<template>.*?)</template>",
    re.S,
)
MEMBER = re.compile(r"^  (?:@\w+(?:\([^)]*\))?\s+)*(?:get |set |async |static )?#?(\w+)\s*(?:=[^=]|\(|;)", re.M)
# value reads only: `{{@x}}`, `(fn @x)`, `@x.y`; not `@x=` arguments passed to children
ARG_READ = re.compile(r"(?<![\w-])@(\w+)(?=[}\s).|])")


def default_files():
    out = run(
        ["git", "grep", "-lzE", r"""from[[:space:]]+['"]@glimmer/component['"]""", "--",
         "frontend/discourse/*.gjs", "frontend/discourse/*.gts", "plugins/*.gjs", "plugins/*.gts"],
        ok=(0, 1),
    )
    return out.split("\0")[:-1]


def main():
    files = sys.argv[1:] or default_files()
    checked = skipped = failed = hits = 0
    for path in files:
        try:
            with open(path, encoding="utf-8") as f:
                src = f.read()
        except (OSError, UnicodeError) as error:
            failed += 1
            print(f"{path}: could not read component ({error})", file=sys.stderr)
            continue

        component = CLASS.search(src)
        imports = parse_imports(src, full=True)
        if component is None or imports.get(component["base"]) != GLIMMER_DEFAULT:
            skipped += 1
            print(f"{path}: skipped (no supported Glimmer class with an inline template)", file=sys.stderr)
            continue

        checked += 1
        members = set(MEMBER.findall(component["body"])) - {"constructor"}
        shadowed = sorted(members & set(ARG_READ.findall(component["template"])))
        if shadowed:
            hits += 1
            print(f"{path} {component['name']}: {', '.join('@' + name for name in shadowed)}")

    print(
        f"{checked} files checked, {skipped} skipped, {failed} failed, "
        f"{hits} with template args matching own members",
        file=sys.stderr,
    )
    return int(failed > 0)


if __name__ == "__main__":
    raise SystemExit(main())
