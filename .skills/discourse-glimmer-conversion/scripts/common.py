"""Helpers shared by the conversion scripts: git and gh calls, the external checkouts, module
resolution, and the .gjs/.gts neighborhood rule (SKILL.md Step 1)."""

import json
import os
import posixpath
import re
import shutil
import subprocess

# forced-color variables in the environment would put escape codes into git and gh output
PLAIN_ENV = {k: v for k, v in os.environ.items() if k not in ("CLICOLOR_FORCE", "FORCE_COLOR")} | {"NO_COLOR": "1"}
# the default import, alone or alongside named ones (`{ Input }`), under either local name
CLASSIC_IMPORT = r'^import (Component|ClassicComponent)(, \{[^}]*\})? from "@ember/component"'
EXTERNAL = [
    "all-the-plugins/official", "all-the-plugins/third-party",
    "all-the-themes/official", "all-the-themes/third-party",
    "all-the-custom-plugins/plugins", "all-the-custom-themes/themes",
]
SOURCE_EXTS = ("gts", "gjs", "ts", "js")
SEARCH_GLOBS = ("*.gjs", "*.gts", "*.js", "*.ts", "*.hbs", "*.es6")  # themes still load .js.es6
SEARCH_SKIP = ("node_modules", "dist", ".git", "tmp", "public")


def run(args, ok=(0,), stdin=None, text=True):
    """stdout of a command. An exit code outside `ok` is a broken command, not an empty result."""
    if args[0] == "git":
        # an inherited color.ui=always would wrap paths in escape codes
        args = ["git", "-c", "color.ui=never", *args[1:]]
    r = subprocess.run(args, capture_output=True, input=stdin, text=text, env=PLAIN_ENV)
    if r.returncode not in ok:
        err = r.stderr if text else r.stderr.decode("utf-8", "replace")
        raise SystemExit(f"command failed ({r.returncode}): {' '.join(args)}\n{err[:400]}")
    return r.stdout


def read_blobs(ref, paths):
    """File contents at `ref`, from one `git cat-file --batch` call."""
    data = run(["git", "cat-file", "--batch"], stdin="".join(f"{ref}:{p}\n" for p in paths).encode(), text=False)
    blobs, i = {}, 0
    for p in paths:
        nl = data.index(b"\n", i)
        size = int(data[i:nl].split()[2])
        blobs[p] = data[nl + 1 : nl + 1 + size].decode("utf-8", "replace")
        i = nl + 1 + size + 1
    return blobs


def external_dirs():
    base = os.environ.get("ALL_THE_DIR") or os.path.expanduser("~/discourse/all-the")
    return [os.path.join(base, d) for d in EXTERNAL if os.path.isdir(os.path.join(base, d))]


def search_matches(pattern, dirs):
    """Every match of an extended regex in the source files under `dirs`; ripgrep when present."""
    if not dirs:
        return []
    if shutil.which("rg"):
        args = ["rg", "--no-config", "-uu", "-oN", "--no-filename", "-e", pattern]
        args += [a for g in SEARCH_GLOBS for a in ("-g", g)] + [a for d in SEARCH_SKIP for a in ("-g", f"!{d}")]
    else:
        args = ["grep", "-rhoE", pattern] + [f"--include={g}" for g in SEARCH_GLOBS]
        args += [f"--exclude-dir={d}" for d in SEARCH_SKIP]
    return run([*args, "--", *dirs], ok=(0, 1)).splitlines()


def parse_jsonc(text):
    text = re.sub(r"/\*.*?\*/|//[^\n]*", "", text, flags=re.S)
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", text))


def module_roots(prefix, configs):
    """(specifier prefix, source dirs) from the tsconfig `paths` in `configs` (repo-relative path ->
    text), longest prefix first. `prefix` is prepended to every dir: the checkout, or "" for a tree."""
    roots = []
    for cfg, text in configs.items():
        paths = parse_jsonc(text).get("compilerOptions", {}).get("paths", {})
        for spec, targets in paths.items():
            if spec.endswith("/*"):
                dirs = [posixpath.normpath(posixpath.join(prefix, posixpath.dirname(cfg), t[:-2]))
                        for t in targets if t.endswith("/*")]
                roots.append((spec[:-1], list(dict.fromkeys(dirs))))
    return sorted(roots, key=lambda r: -len(r[0]))


def tsconfig_paths(listing):
    return [p for p in listing if p == "frontend/discourse/tsconfig.json"
            or re.fullmatch(r"plugins/[^/]+/tsconfig\.json", p)]


def resolve(spec, importer_dir, roots, exists, prefix=""):
    """Path of the module `spec` imported from `importer_dir`, or None. `exists(path)` tests a path."""

    def existing(path):
        if exists(path):
            return path
        for e in SOURCE_EXTS:
            for cand in (f"{path}.{e}", posixpath.join(path, f"index.{e}")):
                if exists(cand):
                    return cand
        return None

    if spec.startswith("."):
        return existing(posixpath.normpath(posixpath.join(importer_dir, spec)))
    for spec_prefix, dirs in roots:
        if spec.startswith(spec_prefix):
            for d in dirs:
                if hit := existing(posixpath.join(d, spec[len(spec_prefix):])):
                    return hit
    # plugins without a tsconfig follow the standard layout
    if m := re.match(r"discourse/plugins/([^/]+)/(.*)", spec):
        for root in ("assets/javascripts", "admin/assets/javascripts"):
            if hit := existing(posixpath.join(prefix, "plugins", m[1], root, m[2])):
                return hit
    return None


def neighborhood(rel, listdir):
    """The evidence for SKILL.md Step 1's .gjs/.gts rule. `rel` is the component's repo-relative
    path and `listdir(dir)` lists the file names in a repo-relative dir."""
    here, name = posixpath.split(rel)
    base = name.rsplit(".", 1)[0]
    names = [n for n in listdir(here) if not n.endswith(".d.ts")]
    ext = lambda n: n.rsplit(".", 1)[1] if "." in n else ""
    counts = {e: sum(1 for n in names if ext(n) == e) for e in SOURCE_EXTS}
    parts = base.split("-")
    family_prefix = "-".join(parts[:2]) + "-" if len(parts) > 2 else base + "-"
    family = sorted(n for n in names if n.startswith(family_prefix) and n.rsplit(".", 1)[0] != base
                    and ext(n) in SOURCE_EXTS)
    family += sorted(f"{base}/{n}" for n in listdir(posixpath.join(here, base)) if ext(n) in SOURCE_EXTS)
    typed = sum(1 for n in family if ext(n) in ("gts", "ts"))
    if rel.startswith("frontend/discourse/app/ui-kit/"):
        reason = "ui-kit rule"
    elif counts["gts"] > counts["gjs"]:
        reason = "most components in the directory are .gts"
    elif family and typed * 2 > len(family):
        reason = "most of its family is TypeScript"
    else:
        reason = None
    return dict(counts=counts, family_prefix=family_prefix, family=family, reason=reason)
