import assert from "node:assert/strict";
import { test } from "node:test";
import {
  describeBuild,
  labelOf,
  loadReport,
  packageOf,
  stripVersion,
} from "../lib/graph.mjs";
import { baseApp, makeDist } from "./helpers.mjs";

test("id and file name helpers", () => {
  assert.equal(
    stripVersion("@faker-js/faker@10.6.0/dist/index.js"),
    "@faker-js/faker/dist/index.js"
  );
  assert.equal(stripVersion("app/lib/a@b.js"), "app/lib/a@b.js");
  assert.deepEqual(packageOf("@scope/pkg@1.2.3-beta.1/x.js"), {
    name: "@scope/pkg",
    version: "1.2.3-beta.1",
  });
  assert.equal(labelOf("assets/js/jxl_enc-gne50clb.digested.wasm"), "jxl_enc");
});

test("a lazy bundle costs only what it adds to the initial load", () => {
  const build = describeBuild(loadReport(makeDist(baseApp())));

  assert.deepEqual(
    [...build.bundles.get("lazy:admin/compat-modules.js").costChunks],
    ["assets/js/admin-cccc3333.digested.js"]
  );
  assert.equal(build.initial.size, 2);
});

test("loadReport needs a production build, which has brotli sizes", () => {
  const dir = makeDist({ ...baseApp(), emberEnv: "development" });

  assert.throws(() => loadReport(dir), /from a development build/);
});
