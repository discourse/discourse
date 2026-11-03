import { existsSync, readFileSync } from "fs";
import { join } from "path";

export const GRAPH_PATH = "manifest/bundle-graph.json";
export const MAIN_ENTRY = "discourse";
export const UNMAPPED = "(unmapped)";

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

export function loadGraph(distDir) {
  const path = join(distDir, GRAPH_PATH);
  if (!existsSync(path)) {
    throw new Error(
      `${path} is missing. Production builds write it: EMBER_ENV=production pnpm build`
    );
  }
  const graph = JSON.parse(readFileSync(path, "utf8"));
  if (graph.version !== 2) {
    throw new Error(`${path} has unsupported version ${graph.version}`);
  }
  return graph;
}

/**
 * Turns a bundle graph into bundles: entries and lazy import targets, each
 * with the chunks it loads. Shared chunks belong to no bundle; they count
 * toward every bundle whose closure includes them.
 */
export function describeBuild(graph, { mainEntry = MAIN_ENTRY } = {}) {
  const chunks = graph.chunks;
  const mainFile = graph.entries[mainEntry];
  if (!mainFile) {
    throw new Error(`The build has no "${mainEntry}" entry`);
  }

  const closureCache = new Map();
  const closure = (file) => {
    if (!closureCache.has(file)) {
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
      closureCache.set(file, seen);
    }
    return closureCache.get(file);
  };

  const initial = closure(mainFile);
  const bundles = new Map();
  const bundleOfChunk = new Map();

  const entryNames = Object.keys(graph.entries).sort();
  for (const name of entryNames) {
    const file = graph.entries[name];
    const key = `entry:${name}`;
    bundles.set(key, {
      key,
      kind: "entry",
      name,
      file,
      facade: chunks[file].facade,
      isMain: name === mainEntry,
    });
    bundleOfChunk.set(file, key);
  }

  const lazyFiles = Object.keys(chunks)
    .filter(
      (file) =>
        chunks[file].kind === "lazy" &&
        chunks[file].facade &&
        !bundleOfChunk.has(file)
    )
    .sort();
  const strippedCount = new Map();
  for (const file of lazyFiles) {
    const stripped = stripVersion(chunks[file].facade);
    strippedCount.set(stripped, (strippedCount.get(stripped) ?? 0) + 1);
  }
  for (const file of lazyFiles) {
    const facade = chunks[file].facade;
    const stripped = stripVersion(facade);
    const key = `lazy:${strippedCount.get(stripped) > 1 ? facade : stripped}`;
    bundles.set(key, {
      key,
      kind: "lazy",
      name: null,
      file,
      facade,
      isMain: false,
    });
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
  const strippedModuleChunk = new Map();
  for (const [file, chunk] of Object.entries(chunks)) {
    for (const id of Object.keys(chunk.modules)) {
      if (id !== UNMAPPED) {
        moduleChunk.set(id, file);
        strippedModuleChunk.set(stripVersion(id), file);
      }
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
    mainKey: `entry:${mainEntry}`,
    initial,
    bundles,
    bundleOfChunk,
    moduleChunk,
    edges: computeEdges(chunks, bundles, bundleOfChunk, initial),
  };
}

function nameLazyBundles(bundles, chunks) {
  const lazy = [...bundles.values()].filter((b) => b.kind === "lazy");
  const labelCount = new Map();
  for (const bundle of lazy) {
    const label = chunks[bundle.file].label;
    labelCount.set(label, (labelCount.get(label) ?? 0) + 1);
  }
  for (const bundle of lazy) {
    const label = chunks[bundle.file].label;
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
  const add = (from, to, kind, examples) => {
    if (from.key === to.key || initial.has(to.file)) {
      return;
    }
    const key = `${from.key}|${to.key}|${kind}`;
    if (!edges.has(key)) {
      edges.set(key, { from: from.key, to: to.key, kind, examples: [] });
    }
    const edge = edges.get(key);
    for (const example of examples ?? []) {
      if (
        edge.examples.length < 3 &&
        !edge.examples.some(
          (e) => e.from === example.from && e.to === example.to
        )
      ) {
        edge.examples.push(example);
      }
    }
  };

  for (const from of bundles.values()) {
    for (const file of from.costChunks) {
      const chunk = chunks[file];
      if (file !== from.file && bundleOfChunk.has(file)) {
        const to = bundles.get(bundleOfChunk.get(file));
        add(
          from,
          to,
          "static",
          examplesTo(from.costChunks, chunks, "static", file)
        );
      }
      for (const target of chunk.dynamicImports) {
        const to = bundles.get(bundleOfChunk.get(target));
        if (to && !from.closure.has(target)) {
          add(from, to, "dynamic", chunk.examples[`dynamic:${target}`]);
        }
      }
      for (const target of chunk.urlImports) {
        const to = bundles.get(bundleOfChunk.get(target));
        if (to) {
          add(from, to, "url", chunk.examples[`url:${target}`]);
        }
      }
    }
  }
  return edges;
}

function examplesTo(closure, chunks, kind, target) {
  const examples = [];
  for (const file of closure) {
    examples.push(...(chunks[file].examples[`${kind}:${target}`] ?? []));
    if (examples.length >= 3) {
      break;
    }
  }
  return examples;
}

/** Minified bytes per version-less module id over a set of chunks. */
export function moduleBytes(graph, files) {
  const bytes = new Map();
  for (const file of files) {
    for (const [id, size] of Object.entries(graph.chunks[file].modules)) {
      const key = stripVersion(id);
      bytes.set(key, (bytes.get(key) ?? 0) + size);
    }
  }
  return bytes;
}
