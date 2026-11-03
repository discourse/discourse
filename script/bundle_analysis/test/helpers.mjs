import { mkdirSync, mkdtempSync, writeFileSync } from "fs";
import { tmpdir } from "os";
import { dirname, join } from "path";

// Deterministic, poorly compressible text, so brotli sizes track raw sizes.
function text(seed, length) {
  let state = [...seed].reduce(
    (h, c) => (h * 31 + c.charCodeAt(0)) % 2 ** 32,
    7
  );
  let out = "";
  while (out.length < length) {
    state = (state * 1103515245 + 12345) % 2 ** 32;
    out += state.toString(36);
  }
  return out.slice(0, length);
}

/**
 * Writes a fake production build. `chunks` maps a file name to
 * `{ kind, facade?, imports?, dynamicImports?, urlImports?, modules, examples? }`;
 * each module's content depends only on its id, so moving a module between
 * chunks keeps the bytes.
 */
export function makeDist({ entries, chunks, assets = {}, importers = {} }) {
  const dir = mkdtempSync(join(tmpdir(), "bundle-dist-"));
  const graph = { version: 2, entries, chunks: {}, assets: {} };

  for (const [file, chunk] of Object.entries(chunks)) {
    const content = Object.entries(chunk.modules)
      .map(([id, bytes]) => text(id, bytes))
      .join("");
    mkdirSync(dirname(join(dir, file)), { recursive: true });
    writeFileSync(join(dir, file), content);
    graph.chunks[file] = {
      label: file
        .split("/")
        .pop()
        .replace(/-[a-z0-9]+\.digested\.js$/, ""),
      name: "x",
      kind: chunk.kind,
      facade: chunk.facade ?? null,
      imports: chunk.imports ?? [],
      dynamicImports: chunk.dynamicImports ?? [],
      urlImports: chunk.urlImports ?? [],
      modules: chunk.modules,
      examples: chunk.examples ?? {},
    };
  }
  for (const [file, bytes] of Object.entries(assets)) {
    mkdirSync(dirname(join(dir, file)), { recursive: true });
    writeFileSync(join(dir, file), text(file, bytes));
    graph.assets[file] = {
      label: file
        .split("/")
        .pop()
        .replace(/-[a-z0-9]+(\.digested)?\.[a-z0-9]+$/, ""),
    };
  }
  graph.moduleIds = [
    ...new Set(Object.values(chunks).flatMap((c) => Object.keys(c.modules))),
  ].sort();
  graph.importers = graph.moduleIds.map((id) =>
    (importers[id] ?? []).map((importer) => graph.moduleIds.indexOf(importer))
  );
  mkdirSync(join(dir, "manifest"), { recursive: true });
  writeFileSync(join(dir, "manifest/bundle-graph.json"), JSON.stringify(graph));
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
          "dynamic:assets/js/admin-cccc3333.digested.js": [
            { from: "app/app.js", to: "admin/compat-modules.js" },
          ],
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
          "dynamic:assets/js/codemirror-dddd4444.digested.js": [
            { from: "admin/components/a.gjs", to: "app/static/codemirror.js" },
          ],
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
