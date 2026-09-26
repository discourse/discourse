#!/usr/bin/env node
/* eslint-disable no-console */

// why.mjs <module substring> [--from discourse.js]
// Prints the shortest static import chain from the boot entry to each matching module.

import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";

const here = path.dirname(fileURLToPath(import.meta.url));
const GRAPH = path.resolve(
  here,
  "../../frontend/discourse/dist/manifest/module-graph.json"
);

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    from: { type: "string", default: "discourse.js" },
    all: { type: "boolean", default: false },
    importers: { type: "boolean", default: false },
    without: { type: "string" },
    top: { type: "string", default: "15" },
  },
});

const graph = JSON.parse(readFileSync(GRAPH, "utf8"));

// --from may name a module by substring, since virtual ids contain a null byte.
if (!graph[values.from]) {
  const match = Object.keys(graph).find((id) => id.includes(values.from));
  if (match) {
    values.from = match;
  }
}
const [needle] = positionals;

const targets = needle
  ? Object.keys(graph).filter((id) => id.includes(needle))
  : [];
if (needle && !targets.length) {
  console.error(`No module matches ${needle}`);
  process.exit(1);
}

// BFS over static edges only.
const parent = new Map([[values.from, null]]);
const queue = [values.from];
while (queue.length) {
  const current = queue.shift();
  for (const dep of graph[current]?.imports ?? []) {
    if (!parent.has(dep)) {
      parent.set(dep, current);
      queue.push(dep);
    }
  }
}

for (const target of targets) {
  if (values.importers) {
    const importers = Object.entries(graph)
      .filter(([, m]) => m.imports.includes(target))
      .map(([id]) => `${parent.has(id) ? "*" : " "} ${id}`);
    console.log(
      `${target} <- (${importers.length} static importers, * = in boot)`
    );
    console.log(importers.map((i) => `    ${i}`).join("\n"));
    continue;
  }

  if (!parent.has(target)) {
    if (values.all) {
      console.log(`${target}: not in static closure of ${values.from}`);
    }
    continue;
  }

  const chain = [];
  for (let node = target; node; node = parent.get(node)) {
    chain.unshift(node);
  }
  console.log(chain.map((id, i) => `${"  ".repeat(i)}${id}`).join("\n"));
  console.log();
}

// --without <substring>: how much of the boot closure only exists because of the matching modules.
if (values.without) {
  const report = JSON.parse(
    readFileSync(
      path.resolve(
        here,
        "../../frontend/discourse/dist",
        JSON.parse(
          readFileSync(
            path.resolve(
              here,
              "../../frontend/discourse/dist/manifest/manifest.json"
            ),
            "utf8"
          )
        ).bundleAnalysis
      ),
      "utf8"
    )
  );
  const size = new Map();
  for (const chunk of Object.values(report.chunks)) {
    for (const m of chunk.modules) {
      size.set(m.id, (size.get(m.id) ?? 0) + m.renderedLength);
    }
  }
  const removed = new Set(
    Object.keys(graph).filter((id) => id.includes(values.without))
  );
  const reach = (skip) => {
    const seen = new Set();
    const stack = [values.from];
    while (stack.length) {
      const current = stack.pop();
      if (seen.has(current) || skip.has(current)) {
        continue;
      }
      seen.add(current);
      stack.push(...(graph[current]?.imports ?? []));
    }
    return seen;
  };
  const full = reach(new Set());
  const without = reach(removed);
  const only = [...full].filter((id) => !without.has(id));
  const total = only.reduce((sum, id) => sum + (size.get(id) ?? 0), 0);
  console.log(
    `Removing ${[...removed].length} module(s) matching "${values.without}" drops ${only.length} modules, ${(total / 1024).toFixed(1)} KiB rendered:`
  );
  for (const id of only
    .sort((a, b) => (size.get(b) ?? 0) - (size.get(a) ?? 0))
    .slice(0, Number(values.top))) {
    console.log(`  ${String(size.get(id) ?? 0).padStart(8)}  ${id}`);
  }
}
