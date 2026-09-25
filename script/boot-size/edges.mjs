#!/usr/bin/env node
/* eslint-disable no-console */

// edges.mjs <module substring>: for each static import of the module, how much of the
// boot closure would leave if that one import became dynamic.

import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const DIST = path.resolve(here, "../../frontend/discourse/dist");
const graph = JSON.parse(
  readFileSync(path.join(DIST, "manifest/module-graph.json"), "utf8")
);
const manifest = JSON.parse(
  readFileSync(path.join(DIST, "manifest/manifest.json"), "utf8")
);
const report = JSON.parse(
  readFileSync(path.join(DIST, manifest.bundleAnalysis), "utf8")
);

const [needle, from = "discourse.js"] = process.argv.slice(2);
const module = Object.keys(graph).find((id) => id.includes(needle));
if (!module) {
  throw new Error(`No module matches ${needle}`);
}

const size = new Map();
for (const chunk of Object.values(report.chunks)) {
  for (const m of chunk.modules) {
    size.set(m.id, (size.get(m.id) ?? 0) + m.renderedLength);
  }
}

function reach(skipEdge) {
  const seen = new Set();
  const stack = [from];
  while (stack.length) {
    const current = stack.pop();
    if (seen.has(current)) {
      continue;
    }
    seen.add(current);
    for (const dep of graph[current]?.imports ?? []) {
      if (!(current === module && dep === skipEdge)) {
        stack.push(dep);
      }
    }
  }
  return seen;
}

const full = reach(null);
const rows = [];
for (const dep of graph[module].imports) {
  const without = reach(dep);
  let total = 0;
  let count = 0;
  for (const id of full) {
    if (!without.has(id)) {
      total += size.get(id) ?? 0;
      count++;
    }
  }
  rows.push({ dep, total, count });
}
rows.sort((a, b) => b.total - a.total);
let sum = 0;
for (const { dep, total, count } of rows) {
  sum += total;
  if (total > 0) {
    console.log(
      `${(total / 1024).toFixed(1).padStart(8)} KiB  ${String(count).padStart(4)} mods  ${dep}`
    );
  }
}
console.log(
  `sum of individual removals: ${(sum / 1024).toFixed(1)} KiB (overlaps not counted)`
);
