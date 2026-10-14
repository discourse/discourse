#!/usr/bin/env python3
"""Chart classic vs Glimmer component counts per half-year (or quarter), for core and for bundled plugins and themes.

Reads origin/main through git (no checkout) and counts every component the app source defines: each
component class or `.extend(...)`, each `<template>` outside a class body (`const X = <template>`,
inline `renderInOutlet` components), each `templateOnly()`, and each template-only `.hbs` without a
backing module (colocated, or in the older `templates/components/` layout). A class's kind comes from
its superclass, followed through imports and class factories, so `extends ComboBoxComponent` and
`extends buildCategoryPanel(...)` count as classic. Template-only components are Glimmer: colocation
compiles them to `templateOnly()`. Two exceptions are classic: a class-less template in the old
`templates/components/` layout (before `template-only-glimmer-components`, and through a
compatibility shim for plugins and themes after it), and connectors until plugin outlets wrap
class-less ones in `templateOnly()` (February 2023, read per snapshot).

Not counted: route templates, legacy connector objects (`setupComponent` hooks), re-exports, and
the runtime machinery in INFRA.

Usage: .skills/discourse-glimmer-conversion/scripts/component-history.py [--period half|quarter] [--years 4] [--out PATH] [--json PATH]
Run from the core checkout. `git fetch origin main` first.
"""

import argparse
import datetime
import html
import json
import os
import posixpath
import re
import subprocess

REF = "origin/main"
EXTS = (".js", ".gjs", ".ts", ".gts", ".hbs")
# App source only, not build tooling
APP_RE = re.compile(
    r"^(frontend/discourse/(app|admin|select-kit|float-kit|dialog-holder)/"
    r"|app/assets/javascripts/(discourse/app|(admin|select-kit|float-kit|dialog-holder|wizard|discourse-common)/addon)/"
    r"|plugins/[^/]+/(admin/)?assets/javascripts/"
    r"|themes/[^/]+/javascripts/)"
)
DIRS = {"components", "ui-kit", "connectors"}
NOT_COMPONENT_DIRS = {"helpers", "modifiers"}
SKIP_DIRS = {"test", "tests", "spec", "type-tests", "node_modules", "dist", "vendor", "public", "docs",
             "stylesheets", "templates"}
# Runtime machinery that builds component classes for other modules, which count themselves
INFRA = ("/lib/plugin-connectors", "/instance-initializers/component-templates", "/widgets/render-glimmer")
# Import specifier prefix -> source dirs, for both the frontend/ and the app/assets/javascripts/ layout
RULES = [
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
GROUPS = [("core", "Core"), ("bundled", "Bundled plugins and themes")]

IMPORT_RE = re.compile(r'import\s+(\w+)?\s*,?\s*(?:\{([^}]*)\})?\s*from\s+["\']([^"\']+)["\']')
EXPORT_CLASS_RE = re.compile(r"export\s+default\s+(?:@\w+(?:\([^)]*\))?\s+)*class\b[^{]*\bextends\s+(\w+)")
EXPORT_EXTEND_RE = re.compile(r"export\s+default\s+(\w+)\.extend\(")
EXPORT_CALL_RE = re.compile(r"export\s+default\s+(\w+)\(")
EXPORT_NAME_RE = re.compile(r"export\s+default\s+(\w+)\s*;")
REEXPORT_RE = re.compile(r"export\s*\{\s*default\b[^}]*\}\s*from")
CLASSIC = {"@ember/component", "@ember/component/text-field", "@ember/component/text-area",
           "@ember/component/checkbox", "@ember/legacy-built-in-components"}
GLIMMER = {"@glimmer/component", "@ember/component/template-only"}


def run(args, ok=(0,), stdin=None):
    r = subprocess.run(args, capture_output=True, input=stdin)
    if r.returncode not in ok:
        raise SystemExit(f"command failed ({r.returncode}): {' '.join(args)}\n{r.stderr[:400].decode()}")
    return r.stdout


PERIODS = {"half": (6, "H"), "quarter": (3, "Q")}


def snapshots(years, period):
    months, prefix = PERIODS[period]
    today = datetime.date.today()
    current = datetime.date(today.year, (today.month - 1) // months * months + 1, 1)
    start = current.replace(year=current.year - years)
    dates = []
    for y in range(start.year, today.year + 1):
        for m in range(1, 13, months):
            d = datetime.date(y, m, 1)
            if start <= d <= today:
                dates.append(d)
    out = []
    for d in dates:
        sha = run(["git", "rev-list", "-1", "--first-parent", f"--before={d.isoformat()}", REF]).decode().strip()
        if sha:
            out.append((f"{d.year} {prefix}{(d.month - 1) // months + 1}", d.isoformat(), sha))
    head = run(["git", "log", "-1", "--format=%H %cs", REF]).decode().split()
    if not out or out[-1][1] != head[1]:
        out.append(("Now", head[1], head[0]))
    return out


def candidates(sha):
    paths = run(["git", "ls-tree", "-r", "-z", "--name-only", sha]).decode().split("\0")
    return [p for p in paths if APP_RE.match(p) and p.endswith(EXTS) and not p.endswith(".d.ts")
            and not SKIP_DIRS.intersection(module_key(p).split("/")[:-1])]


def module_key(path):
    """Pairs a template from the pre-colocation `templates/components/` layout with its class."""
    return re.sub(r"/templates/(components|connectors)/", r"/\1/", path).rsplit(".", 1)[0]


def show(sha, *paths):
    for p in paths:
        r = subprocess.run(["git", "show", f"{sha}:{p}"], capture_output=True, text=True)
        if r.returncode == 0:
            return r.stdout
    return None


def in_component_dir(path):
    parts = path.split("/")[:-1]
    return bool(DIRS.intersection(parts)) and not NOT_COMPONENT_DIRS.intersection(parts)


def read_blobs(sha, paths):
    data = run(["git", "cat-file", "--batch"], stdin="".join(f"{sha}:{p}\n" for p in paths).encode())
    blobs, i = {}, 0
    for p in paths:
        nl = data.index(b"\n", i)
        size = int(data[i:nl].split()[2])
        blobs[p] = data[nl + 1 : nl + 1 + size].decode("utf-8", "replace")
        i = nl + 1 + size + 1
    return blobs


def group_of(path):
    return "bundled" if path.startswith(("plugins/", "themes/")) else "core"


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


COMMENT_RE = re.compile(r"/\*.*?\*/|^\s*//[^\n]*", re.S | re.M)
CLASS_RE = re.compile(r"(?<![\w$.\-\"'])class(?:\s+(?!extends\b)(\w+))?(?=[\s<])")
EXTEND_DEF_RE = re.compile(r"(?:(?:const|let|var)\s+(\w+)\s*=\s*|export\s+default\s+|[(,]\s*)(\w+)\.extend\(")


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


def classify(sha):
    paths = candidates(sha)
    blobs = read_blobs(sha, [p for p in paths if not p.endswith(".hbs")])
    modules = {}
    for p in paths:
        modules.setdefault(module_key(p), []).append(p)
    # Older plugins kept classes outside the `discourse/` namespace their templates used
    for key in [k for k, files in modules.items() if all(f.endswith(".hbs") for f in files)]:
        alt = re.sub(r"^(plugins/[^/]+/(?:admin/)?assets/javascripts/)discourse/", r"\1", key)
        if alt != key and alt in modules:
            modules[alt] += modules.pop(key)

    # What a class-less connector template renders as at this snapshot
    connectors = show(sha, "frontend/discourse/app/lib/plugin-connectors.js",
                      "app/assets/javascripts/discourse/app/lib/plugin-connectors.js")
    connector_template = "glimmer" if connectors is None or "templateOnly" in connectors else "classic"

    def lone_template(key):
        if "/connectors/" in key:
            return connector_template
        if any("/templates/components/" in p for p in modules[key]):
            return "classic"
        return "glimmer" if in_component_dir(modules[key][0]) else None

    def resolve(source, from_key):
        if source.startswith("."):
            stem = posixpath.normpath(posixpath.join(posixpath.dirname(from_key), source))
            return next((k for k in (stem, f"{stem}/index") if k in modules), None)
        for prefix, dirs in RULES:
            if m := re.match(prefix, source):
                for d in dirs:
                    stem = d.format(*m.groups()) + source[m.end():]
                    if k := next((k for k in (stem, f"{stem}/index") if k in modules), None):
                        return k
        return None

    def src_of(key):
        return next((blobs[p] for p in modules[key] if p in blobs), None)

    memo, local_memo = {}, {}

    def kind(key, seen=()):
        """Kind of the module's default export."""
        if key in memo:
            return memo[key]
        if key in seen:
            return None
        src = src_of(key)
        loose = in_component_dir(modules[key][0])
        if src is None:
            result = lone_template(key)
        else:
            source, factory = superclass(src, loose)
            result = from_source(source, factory, key, (*seen, key))
        memo[key] = result
        return result

    def from_source(source, factory, key, seen, name="default"):
        if source in CLASSIC:
            return "classic"
        if source in GLIMMER:
            return "glimmer"
        if not source or not (target := resolve(source, key)):
            return None
        if factory:
            src = src_of(target)
            return src and defines(src)
        if name != "default" and (named := local_kinds(target, seen).get(name)):
            return named
        return kind(target, seen)

    def local_kinds(key, seen=()):
        """Kinds of the classes a module defines, by local name."""
        if key in local_memo:
            return local_memo[key]
        local_memo[key] = out = {}
        src = src_of(key)
        if src is None:
            return out
        imports = parse_imports(src, full=True)
        defs, _ = definitions(src, modules[key][0])
        for _ in range(3):  # locals may extend locals defined later in the file
            for name, base, factory in defs:
                if name and name not in out:
                    if base in out:
                        out[name] = out[base]
                    elif base in imports:
                        source, orig = imports[base]
                        if k := from_source(source, factory, key, (*seen, key), orig):
                            out[name] = k
        return out

    counts = {g: {"classic": 0, "glimmer": 0, "skipped": 0} for g, _ in GROUPS}
    for key, files in modules.items():
        if key.endswith(INFRA):
            continue
        group = counts[group_of(key)]
        src = src_of(key)
        if src is None:
            group[lone_template(key) or "skipped"] += 1
            continue
        # A legacy connector's class is a plain object; the classic wrapper is the component
        if "/connectors/" in key and connector_template == "classic" and len(files) > 1:
            group["classic"] += 1
            continue
        imports = parse_imports(src, full=True)
        named = local_kinds(key)
        defs, templates = definitions(src, files[0])
        found = templates
        group["glimmer"] += templates
        for name, base, factory in defs:
            if name and name in named:
                k = named[name]
            elif base in named:
                k = named[base]
            elif base in imports:
                k = from_source(*imports[base][:1], factory, key, (key,), imports[base][1])
            else:
                k = None
            if k:
                group[k] += 1
                found += 1
        # `export default factory(...)` defines a component without a class or `.extend` in this file
        if superclass(src, False)[1] and not EXPORT_CLASS_RE.search(src) and "templateOnly(" not in src:
            if k := kind(key):
                group[k] += 1
                found += 1
        if not found and in_component_dir(files[0]) and not reexports(src):
            group["skipped"] += 1
    return counts


CSS = """
:root { color-scheme: light; --surface-1: #fcfcfb; --text-primary: #0b0b0b; --text-secondary: #52514e;
  --text-muted: #8a8984; --grid: #e6e5e1; --series-1: #2a78d6; --series-2: #eb6834; }
@media (prefers-color-scheme: dark) { :root:where(:not([data-theme="light"])) { color-scheme: dark;
  --surface-1: #1a1a19; --text-primary: #f0efec; --text-secondary: #c3c2b7; --text-muted: #8f8e86;
  --grid: #33332f; --series-1: #3987e5; --series-2: #d95926; } }
/* On the page, not a wrapper, so the host sees the surface color past the content */
body { margin: 0; background: var(--surface-1); }
.viz-root { color: var(--text-primary); font: 14px/1.4 system-ui, sans-serif;
  padding: 24px 32px; min-height: 100vh; box-sizing: border-box; }
h1 { font-size: 20px; margin: 0 0 4px; }
.sub { color: var(--text-secondary); margin: 0 0 20px; }
.legend { display: flex; gap: 20px; margin-bottom: 8px; color: var(--text-secondary); }
.legend span::before { content: ""; display: inline-block; width: 10px; height: 10px; border-radius: 2px;
  margin-right: 6px; vertical-align: -1px; background: var(--c); }
.chart { margin: 0 0 32px; position: relative; }
.chart h2 { font-size: 16px; margin: 0 0 8px; }
svg text { fill: var(--text-muted); font-size: 13px; }
svg .cap { fill: var(--text-secondary); font-weight: 600; }
svg .grid { stroke: var(--grid); }
svg .hit { fill: transparent; }
svg .col:hover .seg { opacity: .85; }
/* Ink out-contrasts white on every series fill, in both modes */
svg .in { fill: #0b0b0b; font-weight: 600; }
svg .count { fill: var(--text-secondary); }
.tip { position: fixed; pointer-events: none; background: var(--surface-1); color: var(--text-primary);
  border: 1px solid var(--grid); border-radius: 6px; padding: 8px 10px; box-shadow: 0 4px 12px #0003;
  display: none; white-space: nowrap; }
.tip b { display: block; margin-bottom: 2px; }
.tip i { display: inline-block; width: 8px; height: 8px; border-radius: 2px; margin-right: 6px; }
details { margin-top: 8px; color: var(--text-secondary); }
table { border-collapse: collapse; margin-top: 8px; font-variant-numeric: tabular-nums; }
th, td { padding: 2px 12px 2px 0; text-align: right; }
th:first-child, td:first-child { text-align: left; }
"""

JS = """
const tip = document.querySelector(".tip");
document.querySelectorAll(".col").forEach((col) => {
  col.addEventListener("mousemove", (e) => {
    const d = col.dataset;
    tip.innerHTML = `<b>${d.label} · ${d.date}</b>` +
      `<div><i style="background:var(--series-1)"></i>Glimmer: ${d.glimmer} (${d.share}%)</div>` +
      `<div><i style="background:var(--series-2)"></i>Classic: ${d.classic}</div>` +
      `<div>Total: ${d.total}</div>`;
    tip.style.display = "block";
    tip.style.left = `${Math.min(e.clientX + 14, innerWidth - tip.offsetWidth - 8)}px`;
    tip.style.top = `${e.clientY + 14}px`;
  });
  col.addEventListener("mouseleave", () => (tip.style.display = "none"));
});
"""


def ticks(v):
    """Clean tick step and count (<= 6 intervals) covering v."""
    v = max(v, 5)
    mag = 10 ** (len(str(int(v))) - 1)
    for step in (mag / 10, mag / 5, mag / 4, mag / 2, mag, 2 * mag):
        if step >= 1 and -(-v // step) <= 6:
            return step, int(-(-v // step))
    return 2 * mag, int(-(-v // (2 * mag)))


LABEL_MIN = 18  # px a segment needs to hold its count


def svg_chart(rows, group):
    w, plot_h, left = 960, 252, 50
    step, n = ticks(max(r["counts"][group]["classic"] + r["counts"][group]["glimmer"] for r in rows))
    ymax = step * n
    # Too thin for any classic segment: list all classic counts under the baseline instead
    under = any(0 < r["counts"][group]["classic"] / ymax * plot_h < LABEL_MIN for r in rows)
    bottom = 32 + (20 if under else 0)
    # A Glimmer segment too thin for its count gets it above the bar, under the total
    over = lambda c: c["glimmer"] and (c["glimmer"] - (2 if c["classic"] else 0) * ymax / plot_h) / ymax * plot_h < LABEL_MIN
    top = 22 + (16 if any(over(r["counts"][group]) for r in rows) else 0)
    h = top + plot_h + bottom
    plot_w = w - left - 8
    slot = plot_w / len(rows)
    bar = min(48, slot * 0.6)
    y = lambda v: top + plot_h - v / ymax * plot_h
    out = [f'<svg viewBox="0 0 {w} {h}" width="100%" role="img">']
    for i in range(n + 1):
        v = step * i
        label = f"{v / 1000:g}K" if v >= 1000 else f"{v:g}"
        out.append(f'<line class="grid" x1="{left}" x2="{w - 8}" y1="{y(v):.1f}" y2="{y(v):.1f}"/>')
        out.append(f'<text x="{left - 6}" y="{y(v) + 5:.1f}" text-anchor="end">{label}</text>')
    for i, r in enumerate(rows):
        c = r["counts"][group]
        total = c["classic"] + c["glimmer"]
        share = round(100 * c["glimmer"] / total) if total else 0
        x = left + i * slot + (slot - bar) / 2
        out.append(
            f'<g class="col" data-label="{html.escape(r["label"])}" data-date="{r["date"]}" '
            f'data-classic="{c["classic"]}" data-glimmer="{c["glimmer"]}" data-total="{total}" data-share="{share}">'
        )
        out.append(f'<rect class="hit" x="{left + i * slot:.1f}" y="{top}" width="{slot:.1f}" height="{plot_h}"/>')
        # Classic sits on the baseline; Glimmer stacks on top with a 2px surface gap
        cy = y(c["classic"])
        if c["classic"]:
            out.append(_bar(x, cy, bar, y(0) - cy, "var(--series-2)", 0 if c["glimmer"] else 4))
        if c["glimmer"]:
            gy = y(total)
            out.append(_bar(x, gy, bar, max(cy - gy - (2 if c["classic"] else 0), 1), "var(--series-1)", 4))
        mid = x + bar / 2
        if under and c["classic"]:
            digits = len(str(c["classic"])) * 7.7
            out.append(f'<rect x="{mid - digits / 2 - 6:.1f}" y="{y(0) + 9:.1f}" width="9" height="9" rx="2" fill="var(--series-2)"/>')
            out.append(f'<text class="count" x="{mid + 6:.1f}" y="{y(0) + 18:.1f}" text-anchor="middle">{c["classic"]}</text>')
        elif y(0) - cy >= LABEL_MIN:
            out.append(f'<text class="in" x="{mid:.1f}" y="{(cy + y(0)) / 2 + 5:.1f}" text-anchor="middle">{c["classic"]}</text>')
        cap = y(total) - 5
        if over(c):
            digits = len(str(c["glimmer"])) * 7.7
            out.append(f'<rect x="{mid - digits / 2 - 6:.1f}" y="{cap - 9:.1f}" width="9" height="9" rx="2" fill="var(--series-1)"/>')
            out.append(f'<text class="count" x="{mid + 6:.1f}" y="{cap:.1f}" text-anchor="middle">{c["glimmer"]}</text>')
            cap -= 17
        elif c["glimmer"]:
            out.append(f'<text class="in" x="{mid:.1f}" y="{(y(total) + cy) / 2 + 5:.1f}" text-anchor="middle">{c["glimmer"]}</text>')
        if total:
            out.append(f'<text class="cap" x="{mid:.1f}" y="{cap:.1f}" text-anchor="middle">{total}</text>')
        out.append(f'<text x="{x + bar / 2:.1f}" y="{h - 9}" text-anchor="middle">{html.escape(r["label"])}</text>')
        out.append("</g>")
    out.append("</svg>")
    return "".join(out)


def _bar(x, y, w, h, color, radius):
    # Rounded top corners only; the data-end anchored to the baseline stays square
    r = min(radius, h, w / 2)
    return (
        f'<path class="seg" fill="{color}" d="M{x:.1f},{y + h:.1f} V{y + r:.1f} Q{x:.1f},{y:.1f} {x + r:.1f},{y:.1f} '
        f'H{x + w - r:.1f} Q{x + w:.1f},{y:.1f} {x + w:.1f},{y + r:.1f} V{y + h:.1f} Z"/>'
    )


def table(rows, group):
    body = "".join(
        f"<tr><td>{html.escape(r['label'])}</td><td>{r['date']}</td><td>{r['counts'][group]['classic']}</td>"
        f"<td>{r['counts'][group]['glimmer']}</td><td>{r['counts'][group]['skipped']}</td></tr>"
        for r in rows
    )
    return (
        "<details><summary>Table</summary><table><tr><th>Period</th><th>Commit date</th><th>Classic</th>"
        f"<th>Glimmer</th><th>Not counted</th></tr>{body}</table></details>"
    )


def render(rows, period):
    charts = "".join(
        f'<section class="chart"><h2>{title}</h2>{svg_chart(rows, g)}{table(rows, g)}</section>'
        for g, title in GROUPS
        if any(r["counts"][g]["classic"] + r["counts"][g]["glimmer"] for r in rows)
    )
    return f"""<!doctype html><html><head><meta charset="utf-8"><title>Classic vs Glimmer components</title>
<style>{CSS}</style></head><body><div class="viz-root">
<h1>Classic vs Glimmer components</h1>
<p class="sub">Discourse {REF}, first-parent commit before each {"half-year" if period == "half" else "quarter"} start. Bundled counts grow as plugin and theme repos get merged into core.</p>
<div class="legend"><span style="--c:var(--series-2)">Classic</span><span style="--c:var(--series-1)">Glimmer</span></div>
{charts}<div class="tip"></div></div><script>{JS}</script></body></html>"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--period", choices=PERIODS, default="half")
    ap.add_argument("--years", type=int, default=4)
    ap.add_argument("--out", default="tmp/component-history.html")
    ap.add_argument("--json", help="also write the raw counts here")
    args = ap.parse_args()

    rows = []
    for label, date, sha in snapshots(args.years, args.period):
        counts = classify(sha)
        rows.append({"label": label, "date": date, "sha": sha, "counts": counts})
        summary = "  ".join(f"{g}: {c['classic']}c/{c['glimmer']}g/{c['skipped']}s" for g, c in counts.items())
        print(f"{label:8} {sha[:10]}  {summary}")

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w") as f:
        f.write(render(rows, args.period))
    if args.json:
        with open(args.json, "w") as f:
            json.dump(rows, f, indent=2)
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
