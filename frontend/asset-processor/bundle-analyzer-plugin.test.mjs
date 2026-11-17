/* eslint-disable qunit/require-expect */
import {
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  realpathSync,
  symlinkSync,
  writeFileSync,
} from "fs";
import { tmpdir } from "os";
import { dirname, join } from "path";
import { rolldown } from "rolldown";
import { beforeAll, expect, test, vi } from "vitest";
import brotliAssetsPlugin from "../discourse/lib/brotli-assets-plugin.mjs";
import bundleAnalyzerPlugin from "../discourse/lib/bundle-analyzer-plugin.mjs";
import { normalizeModuleId } from "../discourse/lib/bundle-module-ids.mjs";
import dynamicChunkUrlPlugin from "../discourse/lib/dynamic-chunk-url-plugin.mjs";

const FIXTURE = {
  "main.js": `
    import { shared } from "./shared.js";
    import { merged } from "./merged.js";
    import workerUrl from "virtual:dynamic-chunk-url:./worker.js";
    import pkg from "fake-pkg";
    import { tieZ } from "./tie-z.js";
    import { tieA } from "./tie-a.js";
    const codec = new URL("./codec.wasm", import.meta.url);
    export default [shared, merged, workerUrl, pkg, codec, tieZ, tieA,
      () => import("./lazy.js"), () => import("./merged.js")];
  `,
  "lazy.js": `
    import { shared } from "./shared.js";
    import { lazyOnly } from "./lazy-only.js";
    export default [shared, lazyOnly, () => import("./nested.js")];
  `,
  "nested.js": `
    import { lazyOnly } from "./lazy-only.js";
    export default [lazyOnly, "nested"];
  `,
  "shared.js": `export const shared = ["shared", Math.random()];`,
  "lazy-only.js": `export const lazyOnly = ["lazy only", Math.random()];`,
  "merged.js": `export const merged = ["merged", Math.random()];`,
  "worker.js": `self.postMessage(["worker", Math.random()]);`,
  "tie-z.js": `export const tieZ = ["z", Math.random()];`,
  "tie-a.js": `export const tieA = ["a", Math.random()];`,
  "codec.wasm": "not really wasm",
  "node_modules/.pnpm/fake-pkg@1.2.3/node_modules/fake-pkg/package.json": `{"name":"fake-pkg","version":"1.2.3","main":"index.js"}`,
  "node_modules/.pnpm/fake-pkg@1.2.3/node_modules/fake-pkg/index.js": `export default ["fake", Math.random()];`,
};

function writeFixture() {
  const dir = realpathSync(mkdtempSync(join(tmpdir(), "bundle-graph-")));
  for (const [path, content] of Object.entries(FIXTURE)) {
    mkdirSync(dirname(join(dir, path)), { recursive: true });
    writeFileSync(join(dir, path), content);
  }
  symlinkSync(
    join(dir, "node_modules/.pnpm/fake-pkg@1.2.3/node_modules/fake-pkg"),
    join(dir, "node_modules/fake-pkg")
  );
  return dir;
}

async function build(dir) {
  // The chunk URL plugin names chunks relative to the cwd.
  vi.spyOn(process, "cwd").mockReturnValue(dir);
  const bundle = await rolldown({
    cwd: dir,
    input: { main: join(dir, "main.js") },
    onLog() {},
    experimental: { resolveNewUrlToAsset: true },
    moduleTypes: { ".wasm": "asset" },
    plugins: [
      dynamicChunkUrlPlugin(),
      brotliAssetsPlugin({ enabled: true }),
      bundleAnalyzerPlugin({ root: dir }),
    ],
  });
  const dist = join(dir, "dist");
  await bundle.write({
    dir: dist,
    minify: true,
    hashCharacters: "base36",
    sourcemap: true,
    entryFileNames: "assets/js/[name]-[hash].digested.js",
    chunkFileNames: "assets/js/[name]-[hash].digested.js",
    assetFileNames: "assets/js/[name]-[hash].digested[extname]",
  });
  const reportFile = readdirSync(join(dist, "assets/js")).find((file) =>
    file.startsWith("bundle-analysis-")
  );
  return JSON.parse(readFileSync(join(dist, "assets/js", reportFile), "utf8"));
}

function importersOf(report, id) {
  return report.importers[report.moduleIds.indexOf(id)].map(
    (i) => report.moduleIds[i]
  );
}

function chunkOf(report, facade) {
  return Object.values(report.chunks).find(
    (chunk) => chunk.facadeModuleId === facade
  );
}

let report;
beforeAll(async () => {
  report = await build(writeFixture());
});

test("records how chunks connect, including imports rolldown merged", () => {
  const main = chunkOf(report, "main.js");
  const lazy = chunkOf(report, "lazy.js");
  const nested = chunkOf(report, "nested.js");
  const worker = chunkOf(report, "worker.js");

  expect(report.entrypoints).toEqual([main.file, worker.file].sort());
  expect(main.dynamicImports).toEqual([lazy.file]);
  expect(lazy.dynamicImports).toEqual([nested.file]);
  expect(lazy.dynamicEntryModules).toEqual(["lazy.js"]);
  // merged.js is dynamically imported, but rolldown put it in main.
  expect(main.dynamicEntryModules).toEqual([]);
  expect(main.examples.dynamic[lazy.file]).toEqual({
    from: "main.js",
    to: "lazy.js",
  });
  expect(Object.keys(main.examples.url)).toEqual([worker.file]);
});

test("records every module's static importers", () => {
  expect(importersOf(report, "shared.js")).toEqual(["lazy.js", "main.js"]);
  expect(importersOf(report, "merged.js")).toEqual(["main.js"]);
  expect(importersOf(report, "lazy.js")).toEqual([]);
});

test("records sizes, assets and stable ids, in a stable order", () => {
  const main = chunkOf(report, "main.js");
  const ids = main.modules.map((m) => m.id);

  expect(main.brotliSize).toBeGreaterThan(0);
  expect(ids).toContain("fake-pkg@1.2.3/index.js");
  expect(ids.filter((id) => id.startsWith("tie-"))).toEqual([
    "tie-a.js",
    "tie-z.js",
  ]);
  expect(Object.entries(report.assets)).toEqual([
    [expect.stringMatching(/^assets\/js\/codec-\w+\.digested\.wasm$/), 15],
  ]);
});

test("normalizeModuleId drops machine-specific paths", () => {
  const root = "/repo/frontend/discourse";

  expect(normalizeModuleId(`${root}/app/app.js`, root)).toBe("app/app.js");
  expect(
    normalizeModuleId("/repo/frontend/pretty-text/addon/oneboxer.js", root)
  ).toBe("../pretty-text/addon/oneboxer.js");
  expect(normalizeModuleId("\0rolldown/runtime.js", root)).toBe(
    "virtual:rolldown/runtime.js"
  );
  expect(
    normalizeModuleId(
      `\0virtual:dynamic-chunk-url:${root}/app/workers/entrypoint.js`,
      root
    )
  ).toBe("virtual:dynamic-chunk-url:app/workers/entrypoint.js");
  expect(
    normalizeModuleId(
      "/repo/node_modules/.pnpm/@faker-js+faker@10.6.0/node_modules/@faker-js/faker/dist/index.js",
      root,
      () => "10.6.0"
    )
  ).toBe("@faker-js/faker@10.6.0/dist/index.js");
});
