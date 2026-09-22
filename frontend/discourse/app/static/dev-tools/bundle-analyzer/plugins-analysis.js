import Analysis from "./analysis";
import ChunkTotals from "./chunk-totals";

// Wraps the merged plugin report. Every plugin is built on its own, so sizing is
// per plugin; the flat chunk map underneath is safe because each build prefixes
// its filenames with the plugin's directory.
export default class PluginsAnalysis extends ChunkTotals {
  #graphs = new Map();

  constructor(data) {
    super();
    this.data = data;
    this.plugins = data.plugins;
    this.chunks = Object.fromEntries(
      data.plugins.flatMap((p) => Object.entries(p.chunks))
    );
  }

  // A plugin is a graph of the same shape as core's: entrypoints loaded up
  // front, and bundles loaded on demand — by url here rather than by an
  // `import()` somewhere in the source. Presenting it as an `Analysis` lets a
  // plugin's pane be built from the same cards as the core tab.
  graphFor(plugin) {
    let graph = this.#graphs.get(plugin.plugin);

    if (!graph) {
      graph = new Analysis({
        chunks: plugin.chunks,
        entrypoints: Object.values(plugin.entrypoints),
        dynamicEntrypoints: [...routeBundlesByFile(plugin).keys()],
      });
      // Shared by reference, so the toggle reaches a plugin's own graph as
      // well as the totals on its row.
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

// Route bundle chunk -> the entrypoint that owns it and the urls that load it.
// A plugin usually points a whole group of urls at one bundle.
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
