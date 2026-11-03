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
  const base = fileName.split("/").pop();
  return base.replace(/-[a-z0-9]+\.digested\.[a-z0-9]+$/, "");
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
export function loadGraph(distDir) {
  const path = findReport(distDir);
  if (!path) {
    throw new Error(
      `${distDir} has no bundle analyzer report. Production builds write it: EMBER_ENV=production pnpm build`
    );
  }
  const report = JSON.parse(readFileSync(path, "utf8"));
  if (!report.importers) {
    throw new Error(`${path} predates the module graph`);
  }
  for (const [file, chunk] of Object.entries(report.chunks)) {
    if (!Number.isInteger(chunk.brotliSize)) {
      throw new Error(
        `${path} has no brotli size for ${file}. Production builds write it: EMBER_ENV=production pnpm build`
      );
    }
  }
  return report;
}

/**
 * Turns a bundle analyzer report into bundles: entries and lazy import
 * targets, each with the chunks it loads. Shared chunks belong to no bundle;
 * they count toward every bundle whose closure includes them.
 */
export function describeBuild(graph) {
  const chunks = graph.chunks;
  const entries = new Map(
    graph.entrypoints.map((file) => [chunks[file].name, file])
  );
  const mainFile = entries.get(MAIN_ENTRY);
  if (!mainFile) {
    throw new Error(`The build has no "${MAIN_ENTRY}" entry`);
  }

  const closure = (file) => {
    const seen = new Set([file]);
    const queue = [file];
    while (queue.length) {
      for (const imported of chunks[queue.shift()]?.imports ?? []) {
        if (!seen.has(imported)) {
          seen.add(imported);
          queue.push(imported);
        }
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

  const lazyFacade = new Map();
  for (const file of graph.dynamicEntrypoints) {
    const facade = lazyEntryModule(chunks[file]);
    if (facade && !bundleOfChunk.has(file)) {
      lazyFacade.set(file, facade);
    }
  }
  const lazyFiles = [...lazyFacade.keys()].sort();
  const strippedCount = new Map();
  for (const file of lazyFiles) {
    const stripped = stripVersion(lazyFacade.get(file));
    strippedCount.set(stripped, (strippedCount.get(stripped) ?? 0) + 1);
  }
  for (const file of lazyFiles) {
    const facade = lazyFacade.get(file);
    const stripped = stripVersion(facade);
    const key = `lazy:${strippedCount.get(stripped) > 1 ? facade : stripped}`;
    bundles.set(key, { key, kind: "lazy", name: null, file, facade });
    bundleOfChunk.set(file, key);
  }
  nameLazyBundles(bundles, chunks);

  for (const bundle of bundles.values()) {
    const own = closure(bundle.file);
    bundle.closure = own;
    bundle.costChunks =
      bundle.kind === "lazy"
        ? new Set([...own].filter((file) => !initial.has(file)))
        : own;
  }

  const moduleChunk = new Map();
  const moduleSize = new Map();
  const strippedModuleChunk = new Map();
  for (const [file, chunk] of Object.entries(chunks)) {
    for (const { id, renderedLength } of chunk.modules) {
      moduleChunk.set(id, file);
      moduleSize.set(id, renderedLength);
      strippedModuleChunk.set(stripVersion(id), file);
    }
  }

  const importers = new Map(
    graph.moduleIds.map((id, i) => [
      id,
      graph.importers[i].map((index) => graph.moduleIds[index]),
    ])
  );

  return {
    graph,
    importers,
    strippedModuleChunk,
    initial,
    bundles,
    bundleOfChunk,
    moduleChunk,
    moduleSize,
    edges: computeEdges(chunks, bundles, bundleOfChunk, initial),
  };
}

/**
 * The module a lazy chunk is known by: its facade, else the first module
 * other chunks import from it dynamically. Rolldown gives a dynamically
 * imported chunk no facade when it merges it with other code, so this keeps
 * the bundle's key when that changes between builds.
 */
function lazyEntryModule(chunk) {
  if (chunk.facadeModuleId) {
    return chunk.facadeModuleId;
  }
  return [...(chunk.dynamicEntryModules ?? [])].sort(
    (a, b) =>
      stripVersion(a).localeCompare(stripVersion(b)) || a.localeCompare(b)
  )[0];
}

function nameLazyBundles(bundles, chunks) {
  const lazy = [...bundles.values()].filter((b) => b.kind === "lazy");
  const labelCount = new Map();
  for (const bundle of lazy) {
    const label = chunks[bundle.file].name;
    labelCount.set(label, (labelCount.get(label) ?? 0) + 1);
  }
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
  const nameCount = new Map();
  for (const bundle of lazy) {
    nameCount.set(bundle.name, (nameCount.get(bundle.name) ?? 0) + 1);
  }
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
 * edges come only from the chunks it adds to the initial load; imports in
 * initial-load chunks belong to the main entry.
 */
function computeEdges(chunks, bundles, bundleOfChunk, initial) {
  const edges = new Map();
  const add = (from, to, kind, example) => {
    if (from.key === to.key || initial.has(to.file)) {
      return;
    }
    const key = `${from.key}|${to.key}|${kind}`;
    if (!edges.has(key)) {
      edges.set(key, { from: from.key, to: to.key, kind, example: null });
    }
    edges.get(key).example ??= example ?? null;
  };

  for (const from of bundles.values()) {
    for (const file of from.costChunks) {
      const chunk = chunks[file];
      if (file !== from.file && bundleOfChunk.has(file)) {
        const to = bundles.get(bundleOfChunk.get(file));
        add(from, to, "static", staticExampleTo(from.costChunks, chunks, file));
      }
      for (const target of chunk.dynamicImports) {
        const to = bundles.get(bundleOfChunk.get(target));
        if (to && !from.closure.has(target)) {
          add(from, to, "dynamic", chunk.examples.dynamic[target]);
        }
      }
      for (const [target, example] of Object.entries(chunk.examples.url)) {
        const to = bundles.get(bundleOfChunk.get(target));
        if (to) {
          add(from, to, "url", example);
        }
      }
    }
  }
  return edges;
}

function staticExampleTo(closure, chunks, target) {
  for (const file of closure) {
    const example = chunks[file].examples.static[target];
    if (example) {
      return example;
    }
  }
}
