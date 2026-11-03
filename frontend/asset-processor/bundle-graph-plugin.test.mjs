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
import { expect, test } from "vitest";
import bundleAnalyzerPlugin from "../discourse/lib/bundle-analyzer-plugin.mjs";
import bundleGraphPlugin from "../discourse/lib/bundle-graph-plugin.mjs";
import { normalizeModuleId } from "../discourse/lib/bundle-module-ids.mjs";
import { RESOLVED_PREFIX } from "../discourse/lib/dynamic-chunk-url-plugin.mjs";

const FIXTURE = {
  "main.js": `
    import { shared } from "./shared.js";
    import { merged } from "./merged.js";
    import workerUrl from "virtual:dynamic-chunk-url:./worker.js";
    import pkg from "fake-pkg";
    export default [shared, merged, workerUrl, pkg,
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
  "node_modules/.pnpm/fake-pkg@1.2.3/node_modules/fake-pkg/package.json": `{"name":"fake-pkg","version":"1.2.3","main":"index.js"}`,
  "node_modules/.pnpm/fake-pkg@1.2.3/node_modules/fake-pkg/index.js": `export default ["fake", Math.random()];`,
};

// Same virtual module ids as dynamic-chunk-url-plugin.mjs, which names chunks
// relative to process.cwd() and so cannot build a fixture outside it.
function chunkUrlStandIn() {
  const unresolved = RESOLVED_PREFIX.slice(1);
  return {
    name: "chunk-url-stand-in",
    async resolveId(source, importer) {
      if (source.startsWith(unresolved)) {
        const target = source.slice(unresolved.length);
        const resolved = await this.resolve(target, importer);
        return RESOLVED_PREFIX + resolved.id;
      }
    },
    load(id) {
      if (id.startsWith(RESOLVED_PREFIX)) {
        const ref = this.emitFile({
          type: "chunk",
          id: id.slice(RESOLVED_PREFIX.length),
          name: "worker",
        });
        return `export default import.meta.ROLLUP_FILE_URL_${ref};`;
      }
    },
  };
}

// Precompressed copies, as production builds emit beside every chunk.
function brotliStandIn() {
  return {
    name: "brotli-stand-in",
    generateBundle(_options, bundle) {
      for (const [fileName, output] of Object.entries(bundle)) {
        if (output.type === "chunk") {
          this.emitFile({
            type: "asset",
            fileName: `${fileName}.br`,
            source: "",
          });
        }
      }
    },
  };
}

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
  const bundle = await rolldown({
    cwd: dir,
    input: { main: join(dir, "main.js") },
    onLog() {},
    plugins: [
      chunkUrlStandIn(),
      brotliStandIn(),
      bundleGraphPlugin({ root: dir }),
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
  });
  const readJson = (path) => JSON.parse(readFileSync(join(dist, path), "utf8"));
  const reportFile = readdirSync(join(dist, "assets/js")).find((file) =>
    file.startsWith("bundle-analysis-")
  );
  return {
    graph: readJson("manifest/bundle-graph.json"),
    report: readJson(`assets/js/${reportFile}`),
  };
}

function importersOf(graph, id) {
  return graph.importers[graph.moduleIds.indexOf(id)].map(
    (i) => graph.moduleIds[i]
  );
}

function chunkOf(graph, facade) {
  const entry = Object.entries(graph.chunks).find(
    ([, chunk]) => chunk.facade === facade
  );
  return entry && { file: entry[0], ...entry[1] };
}

test("records entries, lazy chunks and their connections", async () => {
  const { graph } = await build(writeFixture());

  const main = chunkOf(graph, "main.js");
  const lazy = chunkOf(graph, "lazy.js");
  const nested = chunkOf(graph, "nested.js");

  expect(graph.entries.main).toBe(main.file);
  expect(main.kind).toBe("entry");
  expect(main.facade).toBe("main.js");
  expect(lazy.kind).toBe("lazy");
  expect(lazy.facade).toBe("lazy.js");
  expect(main.dynamicImports).toContain(lazy.file);
  expect(lazy.dynamicImports).toContain(nested.file);
  expect(main.examples[`dynamic:${lazy.file}`]).toEqual({
    from: "main.js",
    to: "lazy.js",
  });
  expect(importersOf(graph, "lazy.js")).toEqual([]);
});

test("records a dynamic import that rolldown merged into its importer", async () => {
  const { graph, report } = await build(writeFixture());
  const main = chunkOf(graph, "main.js");

  expect(report.chunks[main.file].modules.map((m) => m.id)).toContain(
    "merged.js"
  );
  expect(main.dynamicImports).not.toContain(main.file);
  expect(importersOf(graph, "merged.js")).toEqual(["main.js"]);
});

test("records every module's static importers", async () => {
  const { graph } = await build(writeFixture());

  expect(importersOf(graph, "shared.js")).toEqual(["lazy.js", "main.js"]);
  expect(importersOf(graph, "lazy-only.js")).toEqual(["lazy.js", "nested.js"]);
});

test("records URL imports created through virtual:dynamic-chunk-url", async () => {
  const { graph } = await build(writeFixture());
  const main = chunkOf(graph, "main.js");
  const worker = chunkOf(graph, "worker.js");

  expect(worker.kind).toBe("entry");
  expect(main.urlImports).toEqual([worker.file]);
});

test("names modules as the bundle analyzer report does", async () => {
  const { graph, report } = await build(writeFixture());
  const reported = Object.values(report.chunks).flatMap((chunk) =>
    chunk.modules.map((m) => m.id)
  );

  expect(reported).toEqual(expect.arrayContaining(graph.moduleIds));
  expect(reported).toContain("fake-pkg@1.2.3/index.js");
});

test("leaves precompressed copies out of the assets", async () => {
  const { graph } = await build(writeFixture());

  expect(graph.assets.filter((f) => f.endsWith(".br"))).toEqual([]);
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
