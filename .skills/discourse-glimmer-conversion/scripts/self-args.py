#!/usr/bin/env python3
"""List template `@name` reads that match a member of the same Glimmer class.

A blanket `this.` -> `@` rewrite turns `{{this.planClick}}` into `{{@planClick}}`, an arg
nobody passes, and nothing errors. Each hit is either that bug or a getter wrapping the arg
it shadows (`get value() { return this.args.value ?? ""; }` next to a `{{@value}}` read);
read every one.

Usage: .skills/discourse-glimmer-conversion/scripts/self-args.py [files...]
With no files, scans every .gjs Glimmer component in core and bundled plugins.
"""

import os
import re
import subprocess
import sys

# forced-color variables in the environment would put escape codes into git output
PLAIN_ENV = {k: v for k, v in os.environ.items() if k not in ("CLICOLOR_FORCE", "FORCE_COLOR")} | {"NO_COLOR": "1"}
CLASS = re.compile(r"export default class (\w+) extends Component \{(.*?)\n  <template>(.*?)</template>", re.S)
MEMBER = re.compile(r"^  (?:@\w+(?:\([^)]*\))?\s+)*(?:get |set |async |static )?#?(\w+)\s*(?:=[^=]|\(|;)", re.M)
# value reads only: `{{@x}}`, `(fn @x)`, `@x.y`; not `@x=` arguments passed to children
ARG_READ = re.compile(r"(?<![\w-])@(\w+)(?=[}\s).|])")


def default_files():
    r = subprocess.run(
        ["git", "-c", "color.ui=never", "grep", "-l", 'from "@glimmer/component"', "--",
         "frontend/discourse/*.gjs", "plugins/*.gjs"],
        capture_output=True, text=True, env=PLAIN_ENV,
    )
    if r.returncode != 0 or not r.stdout.strip():
        raise SystemExit(f"git grep found no Glimmer components; the grep is more likely broken\n{r.stderr[:400]}")
    return r.stdout.split()


def main():
    files = sys.argv[1:] or default_files()
    hits = 0
    for path in files:
        with open(path) as f:
            src = f.read()
        for m in CLASS.finditer(src):
            members = set(MEMBER.findall(m.group(2))) - {"constructor"}
            shadowed = sorted(members & set(ARG_READ.findall(m.group(3))))
            if shadowed:
                hits += 1
                print(f"{path} {m.group(1)}: {', '.join('@' + n for n in shadowed)}")
    print(f"{len(files)} files scanned, {hits} with template args matching own members", file=sys.stderr)


if __name__ == "__main__":
    main()
