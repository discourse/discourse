"""Helpers shared by the conversion scripts: git and gh calls, the external checkouts, module
resolution, the .gjs/.gts neighborhood rule (SKILL.md Step 1), and which modules are classic or
Glimmer components (`Modules`)."""

import json
import os
import posixpath
import re
import shutil
import subprocess

# forced-color variables in the environment would put escape codes into git and gh output
PLAIN_ENV = {k: v for k, v in os.environ.items() if k not in ("CLICOLOR_FORCE", "FORCE_COLOR")} | {"NO_COLOR": "1"}
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


# App source only, not build tooling, in the frontend/ layout and the older app/assets/javascripts/
# one that component-history.py still reads
APP_RE = re.compile(
    r"^(frontend/discourse/(app|admin|select-kit|float-kit|dialog-holder)/"
    r"|app/assets/javascripts/(discourse/app|(admin|select-kit|float-kit|dialog-holder|wizard|discourse-common)/addon)/"
    r"|plugins/[^/]+/(admin/)?assets/javascripts/"
    r"|themes/[^/]+/javascripts/)"
)
MODULE_EXTS = (".js", ".gjs", ".ts", ".gts", ".hbs")
COMPONENT_DIRS = {"components", "ui-kit", "connectors"}
NOT_COMPONENT_DIRS = {"helpers", "modifiers"}
SKIP_DIRS = {"test", "tests", "spec", "type-tests", "node_modules", "dist", "vendor", "public", "docs",
             "stylesheets", "templates"}
# Import specifier prefix -> source dirs, for both layouts
IMPORT_RULES = [
    (r"discourse/plugins/([^/]+)/admin/", ["plugins/{}/admin/assets/javascripts/admin/", "plugins/{}/admin/assets/javascripts/discourse/"]),
    (r"discourse/plugins/([^/]+)/", ["plugins/{}/assets/javascripts/", "plugins/{}/admin/assets/javascripts/"]),
    (r"discourse/admin/", ["frontend/discourse/admin/", "app/assets/javascripts/admin/addon/"]),
    (r"discourse/select-kit/", ["frontend/discourse/select-kit/", "app/assets/javascripts/select-kit/addon/"]),
    (r"discourse/float-kit/", ["frontend/discourse/float-kit/", "app/assets/javascripts/float-kit/addon/"]),
    (r"discourse/form-kit/", ["frontend/discourse/app/form-kit/", "app/assets/javascripts/discourse/app/form-kit/"]),
    (r"discourse/", ["frontend/discourse/app/", "app/assets/javascripts/discourse/app/"]),
    (r"admin/", ["app/assets/javascripts/admin/addon/"]),
    (r"select-kit/", ["app/assets/javascripts/select-kit/addon/"]),
    (r"float-kit/", ["app/assets/javascripts/float-kit/addon/"]),
    (r"dialog-holder/", ["app/assets/javascripts/dialog-holder/addon/"]),
    (r"discourse-common/", ["app/assets/javascripts/discourse-common/addon/"]),
    (r"wizard/", ["app/assets/javascripts/wizard/addon/"]),
]

IMPORT_RE = re.compile(r'import\s+(\w+)?\s*,?\s*(?:\{([^}]*)\})?\s*from\s+["\']([^"\']+)["\']')
EXPORT_DECORATORS = r"export\s+default\s+(?:@\w+(?:\([^)]*\))?\s+)*class"
EXPORT_CLASS_RE = re.compile(EXPORT_DECORATORS + r"\b[^{]*\bextends\s+(\w+)")
EXPORT_CLASS_NAME_RE = re.compile(EXPORT_DECORATORS + r"\s+(?!extends\b)(\w+)")
EXPORT_EXTEND_RE = re.compile(r"export\s+default\s+(\w+)\.extend\(")
EXPORT_CALL_RE = re.compile(r"export\s+default\s+(\w+)\(")
EXPORT_NAME_RE = re.compile(r"export\s+default\s+(\w+)\s*;")
REEXPORT_RE = re.compile(r"export\s*\{\s*default\b[^}]*\}\s*from")
CLASSIC = {"@ember/component", "@ember/component/text-field", "@ember/component/text-area",
           "@ember/component/checkbox", "@ember/legacy-built-in-components"}
GLIMMER = {"@glimmer/component", "@ember/component/template-only"}
COMMENT_RE = re.compile(r"/\*.*?\*/|^\s*//[^\n]*", re.S | re.M)
CLASS_RE = re.compile(r"(?<![\w$.\-\"'])class(?:\s+(?!extends\b)(\w+))?(?=[\s<])")
EXTEND_DEF_RE = re.compile(r"(?:(?:const|let|var)\s+(\w+)\s*=\s*|export\s+default\s+|[(,]\s*)(\w+)\.extend\(")


def module_key(path):
    """Pairs a template from the pre-colocation `templates/components/` layout with its class."""
    return re.sub(r"/templates/(components|connectors)/", r"/\1/", path).rsplit(".", 1)[0]


def in_component_dir(path):
    parts = path.split("/")[:-1]
    return bool(COMPONENT_DIRS.intersection(parts)) and not NOT_COMPONENT_DIRS.intersection(parts)


def default_export_name(src):
    """The name the default export is defined under: `export default class X`, or `export default X;`
    for a class built with `X = Component.extend(...)`."""
    m = EXPORT_CLASS_NAME_RE.search(src) or EXPORT_NAME_RE.search(src)
    return m and m.group(1)


def parse_imports(src, full=False):
    """Local name -> source, or -> (source, imported name) with `full`."""
    imports = {}
    for default, named, source in IMPORT_RE.findall(src):
        if default:
            imports[default] = (source, "default") if full else source
        for spec in (named or "").split(","):
            if spec := spec.strip().removeprefix("type "):
                orig, _, local = spec.partition(" as ")
                imports[(local or orig).strip()] = (source, orig.strip()) if full else source
    return imports


def body_end(code, start):
    depth = 0
    for i in range(start, len(code)):
        if code[i] == "{":
            depth += 1
        elif code[i] == "}":
            depth -= 1
            if depth == 0:
                return i
    return len(code)


def definitions(src, path):
    """[(local name or None, base ident, is_factory)] for classes and `.extend(...)`, plus the number of
    standalone templates and `templateOnly()` calls."""
    code = COMMENT_RE.sub("", src)
    defs, bodies = [], []
    for m in CLASS_RE.finditer(code):
        brace = code.find("{", m.end())
        header = code[m.end() : brace]
        if brace < 0 or len(header) > 500 or ";" in header or (e := list(re.finditer(r"\bextends\s+(\w+)(\s*\()?", header))) == []:
            continue
        defs.append((m.group(1), e[-1].group(1), bool(e[-1].group(2))))
        bodies.append((brace, body_end(code, brace)))
    for m in EXTEND_DEF_RE.finditer(code):
        defs.append((m.group(1), m.group(2), False))
    templates = 0
    if path.endswith((".gjs", ".gts")):
        templates = sum(1 for m in re.finditer(r"<template>", code) if not any(a < m.start() < b for a, b in bodies))
    templates += len(re.findall(r"\btemplateOnly\(\)", code))
    return defs, templates


def superclass(src, loose=True):
    """(import source of the default export's superclass, whether it's a class factory).

    The source is a GLIMMER marker for template-only modules. `loose` also accepts a module that
    merely contains a template, which is only safe inside component directories.
    """
    imports = parse_imports(src)
    if m := EXPORT_CLASS_RE.search(src) or EXPORT_EXTEND_RE.search(src) or EXPORT_NAME_RE.search(src):
        ident = m.group(1)
        if re.search(rf"extends\s+{re.escape(ident)}\s*\(", src) and ident in imports:
            return imports[ident], True
    elif (m := EXPORT_CALL_RE.search(src)) and m.group(1) in imports:
        return imports[m.group(1)], True
    else:
        ident = None
    # Follow local aliases: `const Base = X.extend(...)`, `class Base extends X`
    for _ in range(5):
        if not ident or ident in imports:
            break
        name = re.escape(ident)
        if re.search(rf"(?:const|let)\s+{name}\b[^=]*=\s*<template>", src):
            return "@ember/component/template-only", False
        m = re.search(rf"class\s+{name}\b[^{{]*\bextends\s+(\w+)", src) or re.search(
            rf"(?:const|let)\s+{name}\s*=\s*(\w+)\.extend\(", src
        )
        ident = m and m.group(1)
    if ident:
        return imports.get(ident), False
    # A top-level <template> is the module's implicit default export
    if re.search(r"export\s+default\s+(templateOnly\(|<template>)", src) or re.search(r"^<template>", src, re.M):
        return "@ember/component/template-only", False
    if loose and "<template>" in src and not re.search(r"\bclass\s+\w+[^{]*\bextends\b", src):
        return "@ember/component/template-only", False
    return None, False


def reexports(src):
    """An alias for a module defined elsewhere, which counts there."""
    if REEXPORT_RE.search(src):
        return True
    m = EXPORT_NAME_RE.search(src)
    return bool(m) and m.group(1) in parse_imports(src) and not EXPORT_CLASS_RE.search(src)


def defines(src):
    """For factory modules: which component base the module itself builds on."""
    sources = set(parse_imports(src).values())
    if sources & CLASSIC:
        return "classic"
    if sources & GLIMMER:
        return "glimmer"
    return None


class Modules:
    """The app modules at a git ref, and what each one's default export is: a "classic" or
    "glimmer" component, or None. A class's kind comes from its superclass, followed through
    imports, local aliases and class factories, so `extends DTextField` and
    `extends buildCategoryPanel(...)` count as classic."""

    def __init__(self, ref):
        paths = [p for p in run(["git", "ls-tree", "-r", "-z", "--name-only", ref]).split("\0")
                 if APP_RE.match(p) and p.endswith(MODULE_EXTS) and not p.endswith(".d.ts")
                 and not SKIP_DIRS.intersection(module_key(p).split("/")[:-1])]
        self.blobs = read_blobs(ref, [p for p in paths if not p.endswith(".hbs")])
        self.modules = {}
        for p in paths:
            self.modules.setdefault(module_key(p), []).append(p)
        # Older plugins kept classes outside the `discourse/` namespace their templates used
        for key in [k for k, files in self.modules.items() if all(f.endswith(".hbs") for f in files)]:
            alt = re.sub(r"^(plugins/[^/]+/(?:admin/)?assets/javascripts/)discourse/", r"\1", key)
            if alt != key and alt in self.modules:
                self.modules[alt] += self.modules.pop(key)
        # What a class-less connector template renders as at this ref
        connectors = next((self.blobs[p] for p in ("frontend/discourse/app/lib/plugin-connectors.js",
                                                   "app/assets/javascripts/discourse/app/lib/plugin-connectors.js")
                           if p in self.blobs), None)
        self.connector_template = "glimmer" if connectors is None or "templateOnly" in connectors else "classic"
        self._kinds, self._local_kinds, self._parsed = {}, {}, {}

    def classic(self, roots):
        """Source files under `roots` whose default export is a classic component, re-exports aside."""
        found = []
        for key, files in self.modules.items():
            path = next((p for p in files if p in self.blobs), None)
            if path and path.startswith(roots) and self.kind(key) == "classic" and not reexports(self.blobs[path]):
                found.append(path)
        return sorted(found)

    def bases(self, key):
        """The modules the default export's superclass chain passes through, nearest first."""
        seen = {key}
        while (src := self.src_of(key)) is not None:
            source, _ = superclass(src, in_component_dir(self.modules[key][0]))
            key = source and self.target(source, key)
            if not key or key in seen:
                return
            seen.add(key)
            yield key

    def lone_template(self, key):
        if "/connectors/" in key:
            return self.connector_template
        if any("/templates/components/" in p for p in self.modules[key]):
            return "classic"
        return "glimmer" if in_component_dir(self.modules[key][0]) else None

    def target(self, source, from_key):
        """The module key an import specifier resolves to, or None."""
        if source.startswith("."):
            stem = posixpath.normpath(posixpath.join(posixpath.dirname(from_key), source))
            return next((k for k in (stem, f"{stem}/index") if k in self.modules), None)
        for prefix, dirs in IMPORT_RULES:
            if m := re.match(prefix, source):
                for d in dirs:
                    stem = d.format(*m.groups()) + source[m.end():]
                    if k := next((k for k in (stem, f"{stem}/index") if k in self.modules), None):
                        return k
        return None

    def src_of(self, key):
        return next((self.blobs[p] for p in self.modules[key] if p in self.blobs), None)

    def parsed(self, key):
        """A module's imports, local definitions and templates, parsed once."""
        if key not in self._parsed:
            src = self.src_of(key)
            self._parsed[key] = None if src is None else (parse_imports(src, full=True), *definitions(src, self.modules[key][0]))
        return self._parsed[key]

    def kind(self, key, seen=()):
        """Kind of the module's default export."""
        if key in self._kinds:
            return self._kinds[key]
        if key in seen:
            return None
        src = self.src_of(key)
        loose = in_component_dir(self.modules[key][0])
        if src is None:
            result = self.lone_template(key)
        else:
            source, factory = superclass(src, loose)
            result = self.from_source(source, factory, key, (*seen, key))
        self._kinds[key] = result
        return result

    def from_source(self, source, factory, key, seen, name="default"):
        if source in CLASSIC:
            return "classic"
        if source in GLIMMER:
            return "glimmer"
        if not source or not (target := self.target(source, key)):
            return None
        if factory:
            src = self.src_of(target)
            return src and defines(src)
        if name != "default" and (named := self.local_kinds(target, seen).get(name)):
            return named
        return self.kind(target, seen)

    def local_kinds(self, key, seen=()):
        """Kinds of the classes a module defines, by local name."""
        if key in self._local_kinds:
            return self._local_kinds[key]
        self._local_kinds[key] = out = {}
        if (p := self.parsed(key)) is None:
            return out
        imports, defs, _ = p
        for _ in range(3):  # locals may extend locals defined later in the file
            for name, base, factory in defs:
                if name and name not in out:
                    if base in out:
                        out[name] = out[base]
                    elif base in imports:
                        source, orig = imports[base]
                        if k := self.from_source(source, factory, key, (*seen, key), orig):
                            out[name] = k
        return out
