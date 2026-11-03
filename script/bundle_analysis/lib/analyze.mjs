import {
  describeBuild,
  labelOf,
  loadGraph,
  MAIN_KEY,
  packageOf,
  stripVersion,
} from "./graph.mjs";

export const REPORT_SCHEMA = 2;
const TOP_MODULES = 5;
// Smaller module deltas are rebuild noise, e.g. a renumbered import.
const MIN_MODULE_DELTA = 100;

/**
 * Compares two production builds. Returns raw numbers only; thresholds are
 * applied when rendering, so the trusted comment workflow decides what is
 * flagged.
 */
export function analyze({ baseDir, headDir }) {
  const base = describeBuild(loadGraph(baseDir));
  const head = describeBuild(loadGraph(headDir));

  const brotli = (graph, file) => graph.chunks[file].brotliSize;
  const sum = (files, graph) =>
    [...files].reduce((total, file) => total + brotli(graph, file), 0);

  const moved = movedIntoInitialLoad(base, head);

  const bundles = [];
  for (const key of new Set([...base.bundles.keys(), ...head.bundles.keys()])) {
    const b = base.bundles.get(key);
    const h = head.bundles.get(key);
    const measure = (bundle, graph) =>
      bundle
        ? {
            own: brotli(graph, bundle.file),
            load: sum(bundle.costChunks, graph),
          }
        : null;
    bundles.push({
      key,
      name: (h ?? b).name,
      kind: (h ?? b).kind,
      facade: (h ?? b).facade,
      status: !b ? "new" : !h ? "removed" : "same",
      base: measure(b, base.graph),
      head: measure(h, head.graph),
      topModules:
        b && h ? moduleDeltas(base, b.costChunks, head, h.costChunks) : [],
      importedBy: !b && h ? importersOf(key, head) : [],
    });
  }
  bundles.sort((x, y) => (y.head?.load ?? 0) - (x.head?.load ?? 0));

  const newKeys = new Set(
    bundles.filter((b) => b.status === "new").map((b) => b.key)
  );
  const removedKeys = new Set(
    bundles.filter((b) => b.status === "removed").map((b) => b.key)
  );
  const nameOf = new Map(bundles.map((b) => [b.key, b.name]));
  const edgeList = (edges, others, skip) =>
    [...edges]
      .filter(([key]) => !others.has(key))
      .filter(([, edge]) => !skip.has(edge.from) && !skip.has(edge.to))
      .sort(([x], [y]) => x.localeCompare(y))
      .map(([, edge]) => ({
        ...edge,
        fromName: nameOf.get(edge.from),
        toName: nameOf.get(edge.to),
      }));

  return {
    schema: REPORT_SCHEMA,
    initialLoad: {
      base: sum(base.initial, base.graph),
      head: sum(head.initial, head.graph),
      entryOwn: {
        base: brotli(base.graph, base.bundles.get(MAIN_KEY).file),
        head: brotli(head.graph, head.bundles.get(MAIN_KEY).file),
      },
      chunks: { base: base.initial.size, head: head.initial.size },
      topModules: moduleDeltas(base, base.initial, head, head.initial),
    },
    totals: {
      base: sum(chunkFiles(base.graph), base.graph),
      head: sum(chunkFiles(head.graph), head.graph),
      chunks: {
        base: chunkFiles(base.graph).length,
        head: chunkFiles(head.graph).length,
      },
    },
    bundles,
    movedIntoInitialLoad: moved.map((group) => ({
      ...group,
      name: nameOf.get(group.bundle),
    })),
    edges: {
      added: edgeList(head.edges, base.edges, newKeys),
      removed: edgeList(base.edges, head.edges, removedKeys),
    },
    assets: compareAssets(base.graph, head.graph),
    duplicatePackages: duplicatePackages(base.graph, head.graph),
  };
}

function chunkFiles(graph) {
  return Object.keys(graph.chunks);
}

/** Rendered bytes per version-less module id over a set of chunks. */
function moduleBytes(graph, files) {
  const bytes = new Map();
  for (const file of files) {
    for (const { id, renderedLength } of graph.chunks[file].modules) {
      const key = stripVersion(id);
      bytes.set(key, (bytes.get(key) ?? 0) + renderedLength);
    }
  }
  return bytes;
}

/**
 * Modules whose rendered bytes grew most between two sets of chunks. `added`
 * means new to the build, not just to these chunks: moved code is not new.
 */
function moduleDeltas(base, baseFiles, head, headFiles) {
  const before = moduleBytes(base.graph, baseFiles);
  const after = moduleBytes(head.graph, headFiles);
  const deltas = [];
  for (const [id, size] of after) {
    const delta = size - (before.get(id) ?? 0);
    if (delta >= MIN_MODULE_DELTA) {
      deltas.push({ id, delta, added: !base.strippedModuleChunk.has(id) });
    }
  }
  return deltas.sort((a, b) => b.delta - a.delta).slice(0, TOP_MODULES);
}

/** Who imports a new bundle, with the importing module. */
function importersOf(key, build) {
  return [...build.edges.values()]
    .filter((edge) => edge.to === key)
    .map((edge) => ({
      from: edge.from,
      fromName: build.bundles.get(edge.from).name,
      kind: edge.kind,
      example: edge.example,
    }));
}

/**
 * Modules that were only lazily loaded in base but are part of the initial
 * load in head, grouped by the base bundle they came from.
 */
function movedIntoInitialLoad(base, head) {
  const groups = new Map();
  const owners = new Map();
  for (const [id, headFile] of head.moduleChunk) {
    // Version-less, so code that moves in the PR that bumps its package
    // is still found.
    const baseFile =
      base.moduleChunk.get(id) ??
      base.strippedModuleChunk.get(stripVersion(id));
    if (
      !baseFile ||
      base.initial.has(baseFile) ||
      !head.initial.has(headFile)
    ) {
      continue;
    }
    if (!owners.has(baseFile)) {
      owners.set(baseFile, ownerBundle(base, baseFile));
    }
    const owner = owners.get(baseFile);
    if (!owner) {
      continue;
    }
    if (!groups.has(owner.key)) {
      groups.set(owner.key, { bundle: owner.key, bytes: 0, modules: [] });
    }
    const group = groups.get(owner.key);
    const bytes = head.moduleSize.get(id);
    group.bytes += bytes;
    group.modules.push({ id, bytes });
  }

  return [...groups.values()]
    .map((group) => ({
      bundle: group.bundle,
      bytes: group.bytes,
      modules: group.modules
        .sort((a, b) => b.bytes - a.bytes)
        .slice(0, TOP_MODULES),
      importers: boundaryImports(
        base,
        head,
        new Set(group.modules.map((m) => m.id))
      ),
    }))
    .sort((a, b) => b.bytes - a.bytes);
}

/** The lazy bundle whose own chunk holds `file`, else the first whose closure does. */
function ownerBundle(build, file) {
  const direct = build.bundleOfChunk.get(file);
  if (direct) {
    return build.bundles.get(direct);
  }
  return [...build.bundles.values()]
    .filter((bundle) => bundle.kind === "lazy" && bundle.closure.has(file))
    .sort((a, b) => a.key.localeCompare(b.key))[0];
}

/**
 * The imports that pulled moved code in: an initial-load module that did
 * not move itself importing one that did. Importers that were already in the
 * initial load come first, as they are the usual cause.
 */
function boundaryImports(base, head, movedIds) {
  const imports = [];
  for (const id of movedIds) {
    for (const importer of head.importers.get(id) ?? []) {
      if (
        !movedIds.has(importer) &&
        head.initial.has(head.moduleChunk.get(importer))
      ) {
        const wasInitial = base.initial.has(base.moduleChunk.get(importer));
        imports.push({ from: importer, to: id, wasInitial });
      }
    }
  }
  return imports
    .sort(
      (a, b) =>
        b.wasInitial - a.wasInitial ||
        a.from.localeCompare(b.from) ||
        a.to.localeCompare(b.to)
    )
    .slice(0, 3)
    .map(({ from, to }) => ({ from, to }));
}

/** Uncompressed: wasm and worker files get no precompressed copy. */
function compareAssets(baseGraph, headGraph) {
  const byLabel = (graph) => {
    const assets = new Map();
    for (const [file, size] of Object.entries(graph.assets).sort()) {
      let label = labelOf(file);
      for (let n = 2; assets.has(label); n++) {
        label = `${labelOf(file)} (${n})`;
      }
      assets.set(label, size);
    }
    return assets;
  };
  const before = byLabel(baseGraph);
  const after = byLabel(headGraph);
  return [...new Set([...before.keys(), ...after.keys()])]
    .sort()
    .map((label) => ({
      label,
      base: before.get(label) ?? null,
      head: after.get(label) ?? null,
    }));
}

function duplicatePackages(baseGraph, headGraph) {
  const versions = (graph) => {
    const result = new Map();
    for (const chunk of Object.values(graph.chunks)) {
      for (const { id } of chunk.modules) {
        const pkg = packageOf(id);
        if (pkg) {
          if (!result.has(pkg.name)) {
            result.set(pkg.name, new Set());
          }
          result.get(pkg.name).add(pkg.version);
        }
      }
    }
    return result;
  };
  const before = versions(baseGraph);
  return [...versions(headGraph)]
    .filter(([, set]) => set.size > 1)
    .map(([name, set]) => ({
      name,
      versions: [...set].sort(),
      new: (before.get(name)?.size ?? 0) < 2,
    }))
    .sort((a, b) => a.name.localeCompare(b.name));
}
