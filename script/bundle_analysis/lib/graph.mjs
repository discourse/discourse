import { existsSync, readdirSync, readFileSync } from "fs";
import { join } from "path";

const MAIN_ENTRY = "discourse";
export const MAIN_KEY = `entry:${MAIN_ENTRY}`;
const REPORT_DIR = "assets/js";
const REPORT_NAME = /^bundle-analysis-\w+\.digested\.json$/;

// Labels the bundler derives from a module's basename that say nothing about
// the bundle; such bundles are named after their facade instead.
const GENERIC_LABELS = new Set([
  "browser",
  "chunk",
  "dist",
  "esm",
  "index",
  "lib",
  "main",
  "module",
  "src",
]);

const VERSIONED_ID = /^((?:@[^/]+\/)?[^/@]+)@(\d[^/]*)\//;

/** `pkg@1.2.3/x.js` → `pkg/x.js`; other ids are returned unchanged. */
export function stripVersion(id) {
  return id.replace(VERSIONED_ID, "$1/");
}

/** The package name and version of a node_modules id, else `null`. */
export function packageOf(id) {
  const match = id.match(VERSIONED_ID);
  return match ? { name: match[1], version: match[2] } : null;
}

/**
 * The filename part before the content hash, e.g. `admin` for
 * `assets/js/admin-gwfrhsfc.digested.js`. Files without a digested hash
 * keep their whole name. Follows the output file name patterns in the build
 * config.
 */
export function labelOf(fileName) {
  return fileName
    .split("/")
    .pop()
    .replace(/-[a-z0-9]+\.digested\.[a-z0-9]+$/, "");
}

/** The bundle analyzer report in a build, or `null` if it has none. */
export function findReport(distDir) {
  const dir = join(distDir, REPORT_DIR);
  const names = existsSync(dir)
    ? readdirSync(dir).filter((name) => REPORT_NAME.test(name))
    : [];
  if (names.length > 1) {
    throw new Error(`${dir} has ${names.length} bundle analyzer reports`);
  }
  return names[0] ? join(dir, names[0]) : null;
}

/**
 * The bundle analyzer report of a production build, which carries chunk
 * sizes, modules, imports and the module graph.
 */
export function loadReport(distDir) {
  const path = findReport(distDir);
  if (!path) {
    throw new Error(
      `${distDir} has no bundle analyzer report. Production builds write it: EMBER_ENV=production pnpm build`
    );
  }
  const report = JSON.parse(readFileSync(path, "utf8"));
  if (report.emberEnv !== "production") {
    throw new Error(
      `${path} is from a ${report.emberEnv} build, without brotli sizes: EMBER_ENV=production pnpm build`
    );
  }
  if (!report.importers) {
    throw new Error(`${path} predates the module graph`);
  }
  return report;
}

/**
 * Turns a bundle analyzer report into bundles: entries and lazy import
 * targets, each with the chunks it loads. Shared chunks belong to no bundle;
 * they count toward every bundle whose closure includes them.
 */
export function describeBuild(report) {
  const chunks = report.chunks;
  const entries = new Map(
    report.entrypoints.map((file) => [chunks[file].name, file])
  );
  const mainFile = entries.get(MAIN_ENTRY);
  if (!mainFile) {
    throw new Error(`The build has no "${MAIN_ENTRY}" entry`);
  }

  const closure = (file) => {
    const seen = new Set([file]);
    for (const current of seen) {
      for (const imported of chunks[current]?.imports ?? []) {
        seen.add(imported);
      }
    }
    return seen;
  };

  const initial = closure(mainFile);
  const bundles = new Map();
  const bundleOfChunk = new Map();

  for (const [name, file] of [...entries].sort()) {
    const key = `entry:${name}`;
    bundles.set(key, {
      key,
      kind: "entry",
      name,
      file,
      facade: chunks[file].facadeModuleId,
    });
    bundleOfChunk.set(file, key);
  }

  // An import() of code the initial load already has loads nothing.
  const lazy = report.dynamicEntrypoints
    .filter((file) => !initial.has(file))
    .toSorted()
    .map((file) => ({ file, facade: lazyEntryModule(chunks[file]) }))
    .filter(({ facade }) => facade);
  const strippedCount = countBy(lazy, ({ facade }) => stripVersion(facade));
  for (const { file, facade } of lazy) {
    const stripped = stripVersion(facade);
    const key = `lazy:${strippedCount.get(stripped) > 1 ? facade : stripped}`;
    bundles.set(key, { key, kind: "lazy", file, facade });
    bundleOfChunk.set(file, key);
  }
  nameLazyBundles(bundles, chunks);

  for (const bundle of bundles.values()) {
    const loads = closure(bundle.file);
    bundle.costChunks =
      bundle.kind === "lazy"
        ? new Set([...loads].filter((file) => !initial.has(file)))
        : loads;
  }

  const moduleChunk = new Map();
  const strippedModuleId = new Map();
  for (const [file, chunk] of Object.entries(chunks)) {
    for (const { id } of chunk.modules) {
      moduleChunk.set(id, file);
      strippedModuleId.set(stripVersion(id), id);
    }
  }

  const importers = new Map(
    report.moduleIds.map((id, i) => [
      id,
      report.importers[i].map((index) => report.moduleIds[index]),
    ])
  );

  return {
    report,
    importers,
    strippedModuleId,
    initial,
    bundles,
    bundleOfChunk,
    moduleChunk,
    edges: computeEdges(chunks, bundles, bundleOfChunk, initial),
  };
}

/**
 * The module a lazy chunk is known by: its facade, else the first module
 * other chunks import from it dynamically. A dynamically imported chunk has
 * no facade once merged with other code, so this keeps the bundle's key when
 * that changes between builds.
 */
function lazyEntryModule(chunk) {
  return (
    chunk.facadeModuleId ??
    chunk.dynamicEntryModules.toSorted(
      (a, b) =>
        stripVersion(a).localeCompare(stripVersion(b)) || a.localeCompare(b)
    )[0]
  );
}

function nameLazyBundles(bundles, chunks) {
  const lazy = [...bundles.values()].filter((b) => b.kind === "lazy");
  const labelCount = countBy(lazy, (bundle) => chunks[bundle.file].name);
  for (const bundle of lazy) {
    const label = chunks[bundle.file].name;
    const stripped = stripVersion(bundle.facade);
    if (!GENERIC_LABELS.has(label) && labelCount.get(label) === 1) {
      bundle.name = label;
    } else if (packageOf(bundle.facade) && !GENERIC_LABELS.has(label)) {
      bundle.name = `${label} (${stripped})`;
    } else if (packageOf(bundle.facade)) {
      bundle.name = packageOf(bundle.facade).name;
    } else {
      bundle.name = stripped.replace(/\.[a-z]+$/, "");
    }
  }
  const nameCount = countBy(lazy, (bundle) => bundle.name);
  for (const bundle of lazy) {
    if (nameCount.get(bundle.name) > 1) {
      bundle.name = `${bundle.name} (${stripVersion(bundle.facade)})`;
    }
  }
}

/**
 * Bundle A connects to bundle B when loading A loads B (static), can lazily
 * load B (dynamic) or references B's URL (url, for workers). Edges into the
 * initial load are dropped: that code is already loaded. A lazy bundle's
 * edges come only from the chunks it loads beyond the initial load; imports in
 * initial-load chunks belong to the main entry.
 */
function computeEdges(chunks, bundles, bundleOfChunk, initial) {
  const edges = new Map();
  const add = (from, file, kind, example) => {
    const to = bundles.get(bundleOfChunk.get(file));
    if (!to || to === from || initial.has(file)) {
      return;
    }
    const key = `${from.key}|${to.key}|${kind}`;
    if (!edges.has(key)) {
      edges.set(key, { from: from.key, to: to.key, kind, example: null });
    }
    edges.get(key).example ??= example ?? null;
  };

  for (const from of bundles.values()) {
    const staticExamples = [...from.costChunks].map(
      (file) => chunks[file].examples.static
    );
    for (const file of from.costChunks) {
      const chunk = chunks[file];
      add(from, file, "static", staticExamples.find((e) => e[file])?.[file]);
      for (const target of chunk.dynamicImports) {
        if (!from.costChunks.has(target)) {
          add(from, target, "dynamic", chunk.examples.dynamic[target]);
        }
      }
      for (const [target, example] of Object.entries(chunk.examples.url)) {
        add(from, target, "url", example);
      }
    }
  }
  return edges;
}

function countBy(items, keyOf) {
  const counts = new Map();
  for (const item of items) {
    const key = keyOf(item);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return counts;
}
