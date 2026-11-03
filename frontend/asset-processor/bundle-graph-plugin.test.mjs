/* eslint-disable qunit/require-expect */
import {
  mkdirSync,
  mkdtempSync,
  realpathSync,
  symlinkSync,
  writeFileSync,
} from "fs";
import { tmpdir } from "os";
import { dirname, join } from "path";
import { rolldown } from "rolldown";
import { expect, test } from "vitest";
import bundleGraphPlugin, {
  labelOf,
  normalizeModuleId,
} from "../discourse/lib/bundle-graph-plugin.mjs";

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
  const prefix = "\0virtual:dynamic-chunk-url:";
  return {
    name: "chunk-url-stand-in",
    async resolveId(source, importer) {
      if (source.startsWith("virtual:dynamic-chunk-url:")) {
        const target = source.slice("virtual:dynamic-chunk-url:".length);
        const resolved = await this.resolve(target, importer);
        return prefix + resolved.id;
      }
    },
    load(id) {
      if (id.startsWith(prefix)) {
        const ref = this.emitFile({
          type: "chunk",
          id: id.slice(prefix.length),
          name: "worker",
        });
        return `export default import.meta.ROLLUP_FILE_URL_${ref};`;
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
    plugins: [chunkUrlStandIn(), bundleGraphPlugin({ root: dir })],
  });
  const { output } = await bundle.generate({
    dir: join(dir, "dist"),
    minify: true,
    hashCharacters: "base36",
    sourcemap: true,
    entryFileNames: "assets/js/[name]-[hash].digested.js",
    chunkFileNames: "assets/js/[name]-[hash].digested.js",
  });
  const graphFile = output.find(
    (file) => file.fileName === "manifest/bundle-graph.json"
  );
  const code = Object.fromEntries(
    output
      .filter((file) => file.type === "chunk")
      .map((file) => [file.fileName, file.code])
  );
  return {
    graph: JSON.parse(graphFile.source),
    source: graphFile.source,
    code,
  };
}

function importersOf(graph, id) {
  return graph.importers[graph.moduleIds.indexOf(id)].map(
    (i) => graph.moduleIds[i]
  );
}

function chunkByLabel(graph, label) {
  const entry = Object.entries(graph.chunks).find(
    ([, chunk]) => chunk.label === label
  );
  return entry && { file: entry[0], ...entry[1] };
}

test("records entries, lazy chunks and their connections", async () => {
  const { graph } = await build(writeFixture());

  const main = chunkByLabel(graph, "main");
  const lazy = chunkByLabel(graph, "lazy");
  const nested = chunkByLabel(graph, "nested");

  expect(graph.entries.main).toBe(main.file);
  expect(main.kind).toBe("entry");
  expect(main.facade).toBe("main.js");
  expect(lazy.kind).toBe("lazy");
  expect(lazy.facade).toBe("lazy.js");
  expect(main.dynamicImports).toContain(lazy.file);
  expect(lazy.dynamicImports).toContain(nested.file);
  expect(main.examples[`dynamic:${lazy.file}`]).toEqual([
    { from: "main.js", to: "lazy.js" },
  ]);
  expect(importersOf(graph, "lazy.js")).toEqual([]);
});

test("records a dynamic import that rolldown merged into its importer", async () => {
  const { graph } = await build(writeFixture());
  const main = chunkByLabel(graph, "main");

  expect(Object.keys(main.modules)).toContain("merged.js");
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
  const main = chunkByLabel(graph, "main");
  const worker = Object.entries(graph.chunks).find(
    ([, chunk]) => chunk.facade === "worker.js"
  );

  expect(worker[1].kind).toBe("entry");
  expect(main.urlImports).toEqual([worker[0]]);
});

test("attributes every minified byte to a module", async () => {
  const { graph, code } = await build(writeFixture());

  for (const [file, chunk] of Object.entries(graph.chunks)) {
    const total = Object.values(chunk.modules).reduce((a, b) => a + b, 0);
    expect(total, file).toBe(code[file].length);
  }
  expect(chunkByLabel(graph, "main").modules).toHaveProperty([
    "fake-pkg@1.2.3/index.js",
  ]);
});

test("output is identical across builds", async () => {
  const dir = writeFixture();
  const first = await build(dir);
  const second = await build(dir);

  expect(second.source).toBe(first.source);
});

test("labelOf strips the content hash", () => {
  expect(labelOf("assets/js/admin-gwfrhsfc.digested.js")).toBe("admin");
  expect(labelOf("assets/js/route-wizard-js-ab12cd34.digested.js")).toBe(
    "route-wizard-js"
  );
  expect(labelOf("assets/js/jxl_enc-gne50clb.digested.wasm")).toBe("jxl_enc");
  expect(labelOf("@embroider/virtual/test-support.css")).toBe(
    "test-support.css"
  );
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
