import { trustHTML } from "@ember/template";
import BrotliStore from "./brotli-store";

// Strips the assets/js/ prefix and .digested.js suffix for a readable label.
export function stem(file) {
  return file.replace(/^assets\/js\//, "").replace(/\.digested\.js$/, "");
}

export function routeName(chunk) {
  const m = (chunk?.facadeModuleId || "").match(
    /-embroider-route-entrypoint\.js:route=(.+)$/
  );
  return m ? m[1] : null;
}

export function fmt(n) {
  if (n >= 1048576) {
    return (n / 1048576).toFixed(2) + " MB";
  }
  if (n >= 1024) {
    return (n / 1024).toFixed(1) + " KB";
  }
  return n + " B";
}

export function barWidth(length, max) {
  return trustHTML(`width:${Math.max(2, (length / max) * 100)}%`);
}

export function matches(text, filter) {
  return !filter || text.toLowerCase().includes(filter);
}

// Wraps the raw report JSON and answers the graph questions the UI needs:
// static-import closures, per-chunk sizing, and which entrypoints reach a chunk.
export default class Analysis extends BrotliStore {
  brotliCacheKey = "discourse_bundle_analyzer_brotli";

  constructor(data) {
    super();
    this.data = data;
    this.chunks = data.chunks;
    this.entrypoints = data.entrypoints;
    this.dynamicEntrypoints = data.dynamicEntrypoints;
    this.usedByEntries = this.#computeUsedBy();
  }

  urlFor(file) {
    return file;
  }

  staticClosure(file, set = new Set()) {
    if (set.has(file) || !this.chunks[file]) {
      return set;
    }
    set.add(file);
    for (const dep of this.chunks[file].imports) {
      this.staticClosure(dep, set);
    }
    return set;
  }

  closureOf(files) {
    const set = new Set();
    for (const f of files) {
      this.staticClosure(f, set);
    }
    return set;
  }

  // True when a chunk matches the filter by its file path, its name, or any of
  // the source module paths bundled inside it.
  chunkMatches(file, filter) {
    if (!filter) {
      return true;
    }
    const c = this.chunks[file];
    return (
      !!c &&
      (matches(file, filter) ||
        matches(c.name, filter) ||
        c.modules.some((m) => matches(m.id, filter)))
    );
  }

  // Sort key: brotli when we have it, otherwise raw (so ordering is stable
  // before brotli finishes and tightens up as sizes arrive).
  sortSize(file) {
    const c = this.chunks[file];
    if (!c) {
      return 0;
    }
    return this.brotli.get(file) ?? c.rawSize;
  }

  #computeUsedBy() {
    const used = {};
    for (const f of Object.keys(this.chunks)) {
      used[f] = [];
    }
    for (const e of [...this.entrypoints, ...this.dynamicEntrypoints]) {
      for (const f of this.staticClosure(e)) {
        if (used[f] && !used[f].includes(e)) {
          used[f].push(e);
        }
      }
    }
    return used;
  }
}
