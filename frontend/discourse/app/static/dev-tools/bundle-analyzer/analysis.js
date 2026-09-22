import { trustHTML } from "@ember/template";
import ChunkTotals from "./chunk-totals";

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

// Brotli is measured by the build. A set holding a chunk it did not compress
// reads as a dash rather than a total that silently counts that chunk as zero.
export function brotliLabel(totals) {
  return totals.brotliReady ? fmt(totals.brotli) : "—";
}

export function barWidth(length, max) {
  return trustHTML(`width:${Math.max(2, (length / max) * 100)}%`);
}

export function matches(text, filter) {
  return !filter || text.toLowerCase().includes(filter);
}

// Wraps the raw report JSON and answers the graph questions the UI needs:
// static-import closures, per-chunk sizing, and which entrypoints reach a chunk.
export default class Analysis extends ChunkTotals {
  constructor(data) {
    super();
    this.data = data;
    this.chunks = data.chunks;
    this.entrypoints = data.entrypoints;
    this.dynamicEntrypoints = data.dynamicEntrypoints;
    this.usedByEntries = this.#computeUsedBy();
  }

  // Stops at a chunk the view excludes. A chunk's static imports are fetched
  // with it, so a hidden one has nothing loaded beneath it to reach.
  staticClosure(file, set = new Set()) {
    if (set.has(file) || !this.chunks[file] || !this.includes(file)) {
      return set;
    }
    set.add(file);
    for (const dep of this.chunks[file].imports) {
      this.staticClosure(dep, set);
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

  // Sort by what a browser downloads, falling back to raw bytes for a report
  // whose build did not compress.
  sortSize(file) {
    const c = this.chunks[file];
    if (!c) {
      return 0;
    }
    return this.brotliOf(file) ?? c.rawSize;
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
