import {
  describeBuild,
  labelOf,
  loadReport,
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
  const base = describeBuild(loadReport(baseDir));
  const head = describeBuild(loadReport(headDir));
  const pair = (fn) => ({ base: fn(base), head: fn(head) });
  const size = (build, files) =>
    [...files].reduce(
      (total, file) => total + build.report.chunks[file].brotliSize,
      0
    );
  const measure = (bundle, build) =>
    bundle
      ? {
          own: size(build, [bundle.file]),
          load: size(build, bundle.costChunks),
        }
      : null;
  const nameOf = new Map(
    [...base.bundles, ...head.bundles].map(([key, bundle]) => [
      key,
      bundle.name,
    ])
  );
  const named = (edge) => ({
    ...edge,
    fromName: nameOf.get(edge.from),
    toName: nameOf.get(edge.to),
  });
  // Edges `other` lacks, between bundles it has.
  const newEdges = (build, other) =>
    [...build.edges]
      .filter(
        ([key, { from, to }]) =>
          !other.edges.has(key) &&
          other.bundles.has(from) &&
          other.bundles.has(to)
      )
      .sort(([x], [y]) => x.localeCompare(y))
      .map(([, edge]) => named(edge));

  const bundles = [...nameOf.keys()]
    .map((key) => {
      const b = base.bundles.get(key);
      const h = head.bundles.get(key);
      const { name, kind, facade } = h ?? b;
      return {
        key,
        name,
        kind,
        facade,
        status: !b ? "new" : !h ? "removed" : "same",
        base: measure(b, base),
        head: measure(h, head),
        topModules:
          b && h ? moduleDeltas(base, b.costChunks, head, h.costChunks) : [],
        importedBy: b
          ? []
          : [...head.edges.values()].filter((e) => e.to === key).map(named),
      };
    })
    .sort((x, y) => (y.head?.load ?? 0) - (x.head?.load ?? 0));

  return {
    schema: REPORT_SCHEMA,
    initialLoad: {
      ...pair((build) => size(build, build.initial)),
      entryOwn: pair((build) =>
        size(build, [build.bundles.get(MAIN_KEY).file])
      ),
      chunks: pair((build) => build.initial.size),
      topModules: moduleDeltas(base, base.initial, head, head.initial),
    },
    totals: {
      ...pair((build) => size(build, Object.keys(build.report.chunks))),
      chunks: pair((build) => Object.keys(build.report.chunks).length),
    },
    bundles,
    movedIntoInitialLoad: movedIntoInitialLoad(base, head).map((group) => ({
      ...group,
      name: nameOf.get(group.bundle),
    })),
    edges: { added: newEdges(head, base), removed: newEdges(base, head) },
    assets: compareAssets(base.report, head.report),
    duplicatePackages: duplicatePackages(base, head),
  };
}

/** Rendered bytes per version-less module id over a set of chunks. */
function moduleBytes(report, files) {
  const bytes = new Map();
  for (const file of files) {
    for (const { id, renderedLength } of report.chunks[file].modules) {
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
  const before = moduleBytes(base.report, baseFiles);
  const after = moduleBytes(head.report, headFiles);
  const deltas = [];
  for (const [id, size] of after) {
    const delta = size - (before.get(id) ?? 0);
    if (delta >= MIN_MODULE_DELTA) {
      deltas.push({ id, delta, added: !base.strippedModuleId.has(id) });
    }
  }
  return deltas.sort((a, b) => b.delta - a.delta).slice(0, TOP_MODULES);
}

/**
 * Modules that were only lazily loaded in base but are part of the initial
 * load in head, grouped by the base bundle they came from.
 */
function movedIntoInitialLoad(base, head) {
  const groups = new Map();
  for (const file of head.initial) {
    for (const { id, renderedLength: bytes } of head.report.chunks[file]
      .modules) {
      // Version-less, so code that moves in the PR that bumps its package is
      // still found; a second version leaves the base's in place, unmoved.
      const baseVersion = base.strippedModuleId.get(stripVersion(id));
      const baseFile =
        base.moduleChunk.get(id) ??
        (!head.moduleChunk.has(baseVersion) &&
          base.moduleChunk.get(baseVersion));
      const owner =
        baseFile && !base.initial.has(baseFile) && ownerBundle(base, baseFile);
      if (owner) {
        if (!groups.has(owner.key)) {
          groups.set(owner.key, { bundle: owner.key, bytes: 0, modules: [] });
        }
        const group = groups.get(owner.key);
        group.bytes += bytes;
        group.modules.push({ id, bytes });
      }
    }
  }

  return [...groups.values()]
    .map((group) => ({
      ...group,
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

/** The bundle whose own chunk holds `file`, else the first lazy one that loads it. */
function ownerBundle(build, file) {
  return (
    build.bundles.get(build.bundleOfChunk.get(file)) ??
    [...build.bundles.values()]
      .filter((bundle) => bundle.kind === "lazy" && bundle.costChunks.has(file))
      .sort((a, b) => a.key.localeCompare(b.key))[0]
  );
}

/**
 * The imports that pulled moved code in: an initial-load module that did
 * not move itself importing one that did. Importers that were already in the
 * initial load come first, as they are the usual cause.
 */
function boundaryImports(base, head, movedIds) {
  const wasInitial = ({ from }) => base.initial.has(base.moduleChunk.get(from));
  return [...movedIds]
    .flatMap((to) =>
      (head.importers.get(to) ?? [])
        .filter(
          (from) =>
            !movedIds.has(from) && head.initial.has(head.moduleChunk.get(from))
        )
        .map((from) => ({ from, to }))
    )
    .sort(
      (a, b) =>
        wasInitial(b) - wasInitial(a) ||
        a.from.localeCompare(b.from) ||
        a.to.localeCompare(b.to)
    )
    .slice(0, 3);
}

/** Uncompressed: wasm and worker files get no precompressed copy. */
function compareAssets(baseReport, headReport) {
  const byLabel = (report) => {
    const assets = new Map();
    for (const [file, size] of Object.entries(report.assets).sort()) {
      let label = labelOf(file);
      for (let n = 2; assets.has(label); n++) {
        label = `${labelOf(file)} (${n})`;
      }
      assets.set(label, size);
    }
    return assets;
  };
  const before = byLabel(baseReport);
  const after = byLabel(headReport);
  return [...new Set([...before.keys(), ...after.keys()])]
    .sort()
    .map((label) => ({
      label,
      base: before.get(label) ?? null,
      head: after.get(label) ?? null,
    }));
}

function duplicatePackages(base, head) {
  const versions = (build) => {
    const result = new Map();
    for (const id of build.moduleChunk.keys()) {
      const pkg = packageOf(id);
      if (pkg) {
        result.set(
          pkg.name,
          (result.get(pkg.name) ?? new Set()).add(pkg.version)
        );
      }
    }
    return result;
  };
  const before = versions(base);
  return [...versions(head)]
    .filter(([, set]) => set.size > 1)
    .map(([name, set]) => ({
      name,
      versions: [...set].sort(),
      new: (before.get(name)?.size ?? 0) < 2,
    }))
    .sort((a, b) => a.name.localeCompare(b.name));
}
