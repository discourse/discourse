import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { test } from "node:test";
import { compare, readReport, summarize } from "./bundle-analysis.mjs";

function report(size = 256000, suffix = "base") {
  const file = `discourse-${suffix}.js`;
  return {
    emberEnv: "production",
    entrypoints: [file],
    chunks: {
      [file]: {
        name: "discourse",
        rawSize: size * 3,
        brotliSize: size,
        imports: [],
        modules: [{ id: "app.js", renderedLength: size * 3 }],
      },
    },
  };
}

function temporaryDirectory(t) {
  const dir = mkdtempSync(path.join(os.tmpdir(), "bundle-analysis-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  return dir;
}

test("counts shared chunks once, handles cycles, and excludes dynamic imports", () => {
  const data = report(100);
  const main = data.chunks["discourse-base.js"];
  main.imports = ["a", "b"];
  main.dynamicImports = ["lazy"];
  for (const file of ["a", "b", "shared", "lazy"]) {
    data.chunks[file] = {
      ...main,
      imports: [],
      modules: [],
      brotliSize: 10,
      rawSize: 30,
    };
  }
  data.chunks.a.imports = ["shared"];
  data.chunks.b.imports = ["shared"];
  data.chunks.shared.imports = ["a"];
  assert.equal(summarize(data)[0].brotliSize, 130);
  assert.equal(summarize(data)[0].chunks, 4);
});

test("matches logical entrypoints across hashes and catches dependency growth", () => {
  const base = report();
  const head = report(256000, "head");
  head.chunks["discourse-head.js"].imports = ["shared"];
  head.chunks.shared = {
    name: "shared",
    rawSize: 76800,
    brotliSize: 25600,
    imports: [],
    modules: [{ id: "new.js", renderedLength: 76800 }],
  };
  const result = compare(base, head);
  assert.equal(result.failed, true);
  assert.equal(result.percentChange, 10);
  assert.equal(result.moduleChanges[0].status, "added");
});

test("summarizes dynamic entrypoints separately from the startup graph", () => {
  const data = report(100);
  data.dynamicEntrypoints = ["admin-hash.js"];
  data.chunks["admin-hash.js"] = {
    name: "admin",
    rawSize: 60,
    brotliSize: 20,
    imports: ["discourse-base.js"],
    modules: [],
  };
  assert.equal(summarize(data).length, 2);
  assert.equal(summarize(data, "admin")[0].brotliSize, 120);
  assert.equal(summarize(data, "admin-hash.js")[0].kind, "dynamic");
  assert.equal(summarize(data, "discourse")[0].brotliSize, 100);
});

test("requires both thresholds, including equality, and passes decreases", () => {
  assert.equal(compare(report(), report(281600)).failed, true);
  assert.equal(compare(report(), report(281599)).failed, false);
  assert.equal(compare(report(1000), report(1500)).failed, false);
  assert.equal(compare(report(1000000), report(1030000)).failed, false);
  assert.equal(compare(report(), report(200000)).failed, false);
  assert.equal(
    compare(report(), report(), { percent: 0, bytes: 0 }).failed,
    false
  );
  assert.equal(
    compare(report(), report(256001), { percent: 0, bytes: 1 }).failed,
    true
  );
  assert.equal(compare(report(0), report(25600)).failed, true);
});

test("refuses development, incomplete, malformed, and missing-entry reports", () => {
  const data = report();
  assert.throws(
    () => compare({ ...data, emberEnv: "development" }, data),
    /production/
  );
  data.chunks["discourse-base.js"].brotliSize = null;
  assert.equal(summarize(data)[0].brotliSize, null);
  assert.throws(() => compare(data, report()), /Brotli/);
  data.chunks["discourse-base.js"].brotliSize = -1;
  assert.throws(() => summarize(data), /Invalid brotliSize/);
  assert.throws(() => summarize(report(), "missing"), /Entrypoint not found/);
  const missing = report();
  missing.chunks["discourse-base.js"].imports = ["absent"];
  assert.throws(() => compare(missing, report()), /Missing chunk/);
  assert.throws(
    () => compare(report(), report(), { percent: NaN }),
    /Thresholds/
  );
  assert.throws(() => compare(report(), report(), { bytes: -1 }), /Thresholds/);
});

test("discovers the current report from the manifest instead of a stale glob", (t) => {
  const dir = temporaryDirectory(t);
  mkdirSync(path.join(dir, "manifest"));
  writeFileSync(
    path.join(dir, "manifest/manifest.json"),
    JSON.stringify({ bundleAnalysis: "current.json" })
  );
  writeFileSync(path.join(dir, "current.json"), JSON.stringify(report()));
  writeFileSync(path.join(dir, "stale.json"), "invalid JSON");
  assert.deepEqual(readReport(dir), report());
});

test("CLI emits JSON and distinguishes regression from invalid input", (t) => {
  const dir = temporaryDirectory(t);
  const base = path.join(dir, "base.json");
  const head = path.join(dir, "head.json");
  writeFileSync(base, JSON.stringify(report()));
  writeFileSync(head, JSON.stringify(report(384000, "head")));
  const run = (...args) =>
    spawnSync(
      process.execPath,
      [new URL("./bundle-analysis.mjs", import.meta.url).pathname, ...args],
      { encoding: "utf8" }
    );
  const failed = run("diff", base, head, "--json");
  assert.equal(failed.status, 1);
  assert.equal(JSON.parse(failed.stdout).percentChange, 50);
  assert.equal(run("diff", base, base).status, 0);
  assert.equal(run("diff", base, "missing.json").status, 2);
  assert.equal(run("diff", base, head, "--percent", "bad").status, 2);
  assert.equal(run("summary", base, "--unknown").status, 2);
  const summary = run("summary", base, "--json");
  assert.equal(summary.status, 0);
  assert.equal(JSON.parse(summary.stdout).entries[0].name, "discourse");
});
