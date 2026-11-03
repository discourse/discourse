import { mkdirSync, mkdtempSync, writeFileSync } from "fs";
import { tmpdir } from "os";
import { dirname, join } from "path";
import { GRAPH_PATH } from "../lib/graph.mjs";

export const REPORT = "assets/js/bundle-analysis-abcdef123456.digested.json";

/**
 * Writes a fake production build: the bundle graph, the bundle analyzer
 * report with its sizes, and asset files. `chunks` maps a file name to
 * `{ kind, facade?, imports?, dynamicImports?, urlImports?, modules, examples? }`
 * with `modules` as id → bytes; a chunk's brotli size is the sum of its
 * module bytes. `assets` maps a file name to its size.
 */
export function makeDist({ entries, chunks, assets = {}, importers = {} }) {
  const dir = mkdtempSync(join(tmpdir(), "bundle-dist-"));
  const graph = {
    version: 5,
    entries,
    chunks: {},
    assets: Object.keys(assets),
  };
  const report = { chunks: {} };

  for (const [file, chunk] of Object.entries(chunks)) {
    graph.chunks[file] = {
      kind: chunk.kind,
      facade: chunk.facade ?? null,
      imports: chunk.imports ?? [],
      dynamicImports: chunk.dynamicImports ?? [],
      urlImports: chunk.urlImports ?? [],
      examples: chunk.examples ?? {},
    };
    report.chunks[file] = {
      brotliSize: Object.values(chunk.modules).reduce((a, b) => a + b, 0),
      modules: Object.entries(chunk.modules).map(([id, renderedLength]) => ({
        id,
        renderedLength,
      })),
    };
  }
  for (const [file, bytes] of Object.entries(assets)) {
    mkdirSync(dirname(join(dir, file)), { recursive: true });
    writeFileSync(join(dir, file), "x".repeat(bytes));
  }
  graph.moduleIds = [
    ...new Set(Object.values(chunks).flatMap((c) => Object.keys(c.modules))),
  ].sort();
  graph.importers = graph.moduleIds.map((id) =>
    (importers[id] ?? []).map((importer) => graph.moduleIds.indexOf(importer))
  );
  mkdirSync(dirname(join(dir, GRAPH_PATH)), { recursive: true });
  writeFileSync(join(dir, GRAPH_PATH), JSON.stringify(graph));
  mkdirSync(dirname(join(dir, REPORT)), { recursive: true });
  writeFileSync(join(dir, REPORT), JSON.stringify(report));
  return dir;
}

/** A small app: an entry, a shared chunk, and admin and editor bundles. */
export function baseApp(overrides = {}) {
  return {
    entries: { discourse: "assets/js/discourse-aaaa1111.digested.js" },
    chunks: {
      "assets/js/discourse-aaaa1111.digested.js": {
        kind: "entry",
        facade: "discourse.js",
        imports: ["assets/js/chunk-bbbb2222.digested.js"],
        dynamicImports: ["assets/js/admin-cccc3333.digested.js"],
        modules: { "discourse.js": 40000, "app/app.js": 30000 },
        examples: {
          "dynamic:assets/js/admin-cccc3333.digested.js": {
            from: "app/app.js",
            to: "admin/compat-modules.js",
          },
        },
      },
      "assets/js/chunk-bbbb2222.digested.js": {
        kind: "shared",
        modules: { "moment@2.30.1/moment.js": 20000 },
      },
      "assets/js/admin-cccc3333.digested.js": {
        kind: "lazy",
        facade: "admin/compat-modules.js",
        imports: ["assets/js/chunk-bbbb2222.digested.js"],
        dynamicImports: ["assets/js/codemirror-dddd4444.digested.js"],
        modules: {
          "admin/compat-modules.js": 30000,
          "admin/components/a.gjs": 10000,
        },
        examples: {
          "dynamic:assets/js/codemirror-dddd4444.digested.js": {
            from: "admin/components/a.gjs",
            to: "app/static/codemirror.js",
          },
        },
      },
      "assets/js/codemirror-dddd4444.digested.js": {
        kind: "lazy",
        facade: "app/static/codemirror.js",
        modules: {
          "app/static/codemirror.js": 5000,
          "@codemirror/view@6.1.0/dist/index.js": 20000,
        },
      },
      ...overrides,
    },
    importers: {},
  };
}

export const BUDGET = {
  initialLoad: { percent: 1, kib: 10, combine: "or" },
  bundles: { percent: 3, kib: 2, combine: "and" },
  movedIntoInitialLoad: { kib: 1 },
};
