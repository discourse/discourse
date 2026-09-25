#!/usr/bin/env node
/* eslint-disable no-console */

// Sizes the JavaScript a first page view loads: the boot entrypoint's static
// closure, plus the route bundle for the page. Appends to history.json.

import { execSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";

const here = path.dirname(fileURLToPath(import.meta.url));
const DIST = path.resolve(here, "../../frontend/discourse/dist");
const HISTORY = path.join(here, "history.json");

const { values } = parseArgs({
  options: {
    label: { type: "string" },
    save: { type: "boolean", default: false },
    json: { type: "boolean", default: false },
  },
});

const manifest = JSON.parse(
  readFileSync(path.join(DIST, "manifest/manifest.json"), "utf8")
);
const report = JSON.parse(
  readFileSync(path.join(DIST, manifest.bundleAnalysis), "utf8")
);

if (report.emberEnv !== "production") {
  throw new Error("Measure a production build");
}

function closure(files) {
  const seen = new Set();
  const visit = (file) => {
    if (seen.has(file)) {
      return;
    }
    seen.add(file);
    for (const dep of report.chunks[file].imports) {
      visit(dep);
    }
  };
  files.forEach(visit);
  return seen;
}

function sizes(files) {
  let brotli = 0;
  let raw = 0;
  for (const file of files) {
    brotli += report.chunks[file].brotliSize;
    raw += report.chunks[file].rawSize;
  }
  return { brotli, raw, chunks: files.size };
}

function routeChunks(bundleName) {
  const entry = manifest.routeBundles.find((b) => b.bundleName === bundleName);
  if (!entry) {
    throw new Error(`No route bundle named ${bundleName}`);
  }
  return [entry.fileName, ...(entry.preloads ?? [])];
}

const boot = manifest.entrypoints.discourse;
const pages = {
  boot: closure([boot]),
  discovery: closure([boot, ...routeChunks("discovery")]),
  topic: closure([boot, ...routeChunks("topic")]),
};

const result = {
  commit: execSync("git rev-parse --short HEAD").toString().trim(),
  label: values.label ?? execSync("git log -1 --format=%s").toString().trim(),
  date: new Date().toISOString(),
  ...Object.fromEntries(
    Object.entries(pages).map(([name, files]) => [name, sizes(files)])
  ),
};

if (values.json) {
  console.log(JSON.stringify(result, null, 2));
} else {
  const kib = (n) => `${(n / 1024).toFixed(1)} KiB`;
  console.log(`${result.commit} ${result.label}`);
  for (const name of Object.keys(pages)) {
    const { brotli, raw, chunks } = result[name];
    console.log(
      `  ${name.padEnd(10)} ${kib(brotli).padStart(12)} br ${kib(raw).padStart(12)} raw  (${chunks} chunks)`
    );
  }
}

if (values.save) {
  let history = [];
  try {
    history = JSON.parse(readFileSync(HISTORY, "utf8"));
  } catch {}
  history = history.filter((row) => row.label !== result.label);
  history.push(result);
  writeFileSync(HISTORY, JSON.stringify(history, null, 2) + "\n");
}
