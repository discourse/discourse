import BrotliStore from "./brotli-store";

// Wraps the merged plugin report. Every plugin is built on its own, so sizing is
// per plugin; the flat chunk map underneath exists for the brotli pass, and is
// safe because each build prefixes its filenames with the plugin's directory.
export default class PluginsAnalysis extends BrotliStore {
  brotliCacheKey = "discourse_bundle_analyzer_brotli_plugins";

  constructor(data) {
    super();
    this.data = data;
    this.plugins = data.plugins;
    this.chunks = Object.fromEntries(
      data.plugins.flatMap((p) => Object.entries(p.chunks))
    );
  }

  urlFor(file) {
    return `assets/js/plugins/${file}`;
  }

  // Everything a plugin's entrypoint pulls in synchronously.
  closureOf(plugin, file, set = new Set()) {
    if (!file || set.has(file) || !plugin.chunks[file]) {
      return set;
    }
    set.add(file);
    for (const dep of plugin.chunks[file].imports) {
      this.closureOf(plugin, dep, set);
    }
    return set;
  }

  totalsFor(plugin) {
    return this.totals(Object.keys(plugin.chunks));
  }
}
