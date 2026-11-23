import { mkdirSync, mkdtempSync, writeFileSync } from "fs";
import { tmpdir } from "os";
import { dirname, join } from "path";
import { analyze, REPORT_SCHEMA } from "../lib/analyze.mjs";
import { labelOf } from "../lib/graph.mjs";

const REPORT = "assets/js/bundle-analysis-abcdef123456.digested.json";

/**
 * Writes a fake production build's bundle analyzer report. `entries` maps an
 * entry name to its file; `chunks` maps a file name to
 * `{ facade?, imports?, dynamicImports?, dynamicEntryModules?, modules,
 * examples? }` with `modules` as id → bytes and `examples` as kind → target
 * file → example; a chunk's brotli size is the sum of its module bytes.
 */
export function makeDist({
  entries,
  chunks,
  importers = {},
  emberEnv = "production",
}) {
  const dir = mkdtempSync(join(tmpdir(), "bundle-dist-"));
  const entryName = new Map(
    Object.entries(entries).map(([name, file]) => [file, name])
  );
  const moduleIds = [
    ...new Set(Object.values(chunks).flatMap((c) => Object.keys(c.modules))),
  ].sort();
  const dynamicTargets = new Set(
    Object.values(chunks).flatMap((c) => c.dynamicImports ?? [])
  );
  const report = {
    emberEnv,
    entrypoints: Object.values(entries),
    dynamicEntrypoints: Object.keys(chunks).filter(
      (file) => !entryName.has(file) && dynamicTargets.has(file)
    ),
    chunks: {},
    assets: {},
    moduleIds,
    importers: moduleIds.map((id) =>
      (importers[id] ?? []).map((importer) => moduleIds.indexOf(importer))
    ),
  };

  for (const [file, chunk] of Object.entries(chunks)) {
    report.chunks[file] = {
      name: entryName.get(file) ?? labelOf(file),
      facadeModuleId: chunk.facade ?? null,
      brotliSize: Object.values(chunk.modules).reduce((a, b) => a + b, 0),
      imports: chunk.imports ?? [],
      modules: Object.entries(chunk.modules).map(([id, renderedLength]) => ({
        id,
        renderedLength,
      })),
      dynamicImports: chunk.dynamicImports ?? [],
      dynamicEntryModules: chunk.dynamicEntryModules ?? [],
      examples: { static: {}, dynamic: {}, url: {}, ...chunk.examples },
    };
  }
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
        facade: "discourse.js",
        imports: ["assets/js/chunk-bbbb2222.digested.js"],
        dynamicImports: ["assets/js/admin-cccc3333.digested.js"],
        modules: { "discourse.js": 40000, "app/app.js": 30000 },
        examples: {
          dynamic: {
            "assets/js/admin-cccc3333.digested.js": {
              from: "app/app.js",
              to: "admin/compat-modules.js",
            },
          },
        },
      },
      "assets/js/chunk-bbbb2222.digested.js": {
        modules: { "moment@2.30.1/moment.js": 20000 },
      },
      "assets/js/admin-cccc3333.digested.js": {
        facade: "admin/compat-modules.js",
        imports: ["assets/js/chunk-bbbb2222.digested.js"],
        dynamicImports: ["assets/js/codemirror-dddd4444.digested.js"],
        modules: {
          "admin/compat-modules.js": 30000,
          "admin/components/a.gjs": 10000,
        },
        examples: {
          dynamic: {
            "assets/js/codemirror-dddd4444.digested.js": {
              from: "admin/components/a.gjs",
              to: "app/static/codemirror.js",
            },
          },
        },
      },
      "assets/js/codemirror-dddd4444.digested.js": {
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

export const NO_JS_REPORT = { schema: REPORT_SCHEMA, noJsChanges: true };

/** A report of two identical builds; `overrides` replace top-level fields. */
export function emptyReport(overrides = {}) {
  const report = analyze({
    baseDir: makeDist(baseApp()),
    headDir: makeDist(baseApp()),
  });
  return { ...JSON.parse(JSON.stringify(report)), ...overrides };
}
