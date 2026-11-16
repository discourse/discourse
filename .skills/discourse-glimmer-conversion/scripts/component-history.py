#!/usr/bin/env python3
"""Chart classic vs Glimmer component counts per half-year (or quarter), for core and for bundled plugins and themes.

Reads origin/main through git (no checkout) and counts every component the app source defines: each
component class or `.extend(...)`, each `<template>` outside a class body (`const X = <template>`,
inline `renderInOutlet` components), each `templateOnly()`, and each template-only `.hbs` without a
backing module (colocated, or in the older `templates/components/` layout). A class's kind comes from
its superclass, followed through imports and class factories (`Modules` in common.py), so
`extends ComboBoxComponent` and `extends buildCategoryPanel(...)` count as classic. Template-only
components are Glimmer: colocation compiles them to `templateOnly()`. Two exceptions are classic: a class-less template in the old
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

from common import EXPORT_CLASS_RE, Modules, in_component_dir, reexports, run, superclass

REF = "origin/main"
# Runtime machinery that builds component classes for other modules, which count themselves
INFRA = ("/lib/plugin-connectors", "/instance-initializers/component-templates", "/widgets/render-glimmer")
GROUPS = [("core", "Core"), ("bundled", "Bundled plugins and themes")]
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
        # a bare date takes the current time of day, which would move snapshots between runs
        sha = run(["git", "rev-list", "-1", "--first-parent", f"--before={d.isoformat()}T00:00:00Z", REF]).strip()
        if sha:
            out.append((f"{d.year} {prefix}{(d.month - 1) // months + 1}", d.isoformat(), sha))
    head = run(["git", "log", "-1", "--format=%H %cs", REF]).split()
    if not out or out[-1][1] != head[1]:
        out.append(("Now", head[1], head[0]))
    return out


def group_of(path):
    return "bundled" if path.startswith(("plugins/", "themes/")) else "core"


def classify(sha):
    m = Modules(sha)
    counts = {g: {"classic": 0, "glimmer": 0, "skipped": 0} for g, _ in GROUPS}
    for key, files in m.modules.items():
        if key.endswith(INFRA):
            continue
        group = counts[group_of(key)]
        src = m.src_of(key)
        if src is None:
            group[m.lone_template(key) or "skipped"] += 1
            continue
        # A legacy connector's class is a plain object; the classic wrapper is the component
        if "/connectors/" in key and m.connector_template == "classic" and len(files) > 1:
            group["classic"] += 1
            continue
        named = m.local_kinds(key)
        imports, defs, templates = m.parsed(key)
        found = templates
        group["glimmer"] += templates
        for name, base, factory in defs:
            if name and name in named:
                k = named[name]
            elif base in named:
                k = named[base]
            elif base in imports:
                k = m.from_source(*imports[base][:1], factory, key, (key,), imports[base][1])
            else:
                k = None
            if k:
                group[k] += 1
                found += 1
        # `export default factory(...)` defines a component without a class or `.extend` in this file
        if superclass(src, False)[1] and not EXPORT_CLASS_RE.search(src) and "templateOnly(" not in src:
            if k := m.kind(key):
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
.legend { display: flex; gap: 20px; margin-bottom: 8px; color: var(--text-secondary); font-size: 16px; }
.legend span::before { content: ""; display: inline-block; width: 12px; height: 12px; border-radius: 2px;
  margin-right: 6px; vertical-align: -1px; background: var(--c); }
.chart { margin: 0 0 32px; position: relative; }
.chart h2 { font-size: 16px; margin: 0 0 8px; }
svg text { fill: var(--text-muted); font-size: 13px; }
svg .cap { fill: var(--text-secondary); font-weight: 600; }
svg .grid { stroke: var(--grid); }
svg .hit { fill: transparent; }
svg .col:hover .seg { opacity: .85; }
/* White out-contrasts ink on every series fill in both modes (APCA |Lc| 64-76 vs 34-45) */
svg .in { fill: #fff; font-weight: 600; }
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
<p class="sub">Discourse {REF}, first-parent commit before each {"half-year" if period == "half" else "quarter"} start (UTC). Bundled counts grow as plugin and theme repos get merged into core.</p>
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
