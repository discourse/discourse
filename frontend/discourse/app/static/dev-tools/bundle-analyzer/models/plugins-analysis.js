import Analysis from "./analysis.js";
import ChunkTotals from "./chunk-totals.js";

// Wraps the merged plugin report. Each plugin is built on its own, so sizing is
// per plugin, and one flat chunk map holds them all: a filename carries the
// plugin's directory.
export default class PluginsAnalysis extends ChunkTotals {
  #graphs = new Map();

  constructor(data) {
    super();
    this.plugins = data.plugins;
    this.chunks = Object.fromEntries(
      data.plugins.flatMap((p) => Object.entries(p.chunks))
    );
  }

  // Shaped as an `Analysis` so a plugin's pane is built from the core cards.
  graphFor(plugin) {
    let graph = this.#graphs.get(plugin.plugin);

    if (!graph) {
      graph = new Analysis({
        chunks: plugin.chunks,
        entrypoints: Object.values(plugin.entrypoints),
        dynamicEntrypoints: [...routeBundlesByFile(plugin).keys()],
      });
      graph.loaded = this.loaded;
      graph.view = this.view;
      this.#graphs.set(plugin.plugin, graph);
    }

    return graph;
  }

  totalsFor(plugin) {
    return this.totals(Object.keys(plugin.chunks));
  }
}

// A plugin usually points a group of urls at one bundle, so group them by it.
export function routeBundlesByFile(plugin) {
  const byFile = new Map();

  for (const [entry, bundles] of Object.entries(plugin.routeBundles)) {
    for (const { url, fileName } of bundles) {
      if (!byFile.has(fileName)) {
        byFile.set(fileName, { entry, urls: [] });
      }
      byFile.get(fileName).urls.push(url);
    }
  }

  return byFile;
}
