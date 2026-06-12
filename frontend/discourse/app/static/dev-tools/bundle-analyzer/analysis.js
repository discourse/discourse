import { trustHTML } from "@ember/template";

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
export default class Analysis {
  constructor(data) {
    this.data = data;
    this.chunks = data.chunks;
    this.entrypoints = data.entrypoints;
    this.dynamicEntrypoints = data.dynamicEntrypoints;
    this.usedByEntries = this.#computeUsedBy();
  }

  get chunkCount() {
    return Object.keys(this.chunks).length;
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

  totals(files) {
    let raw = 0;
    let brotli = 0;
    for (const f of files) {
      raw += this.chunks[f].rawSize;
      brotli += this.chunks[f].brotliSize;
    }
    return { files: files.size ?? files.length, raw, brotli };
  }

  size(file, sizeKey) {
    const c = this.chunks[file];
    return c ? (sizeKey === "brotli" ? c.brotliSize : c.rawSize) : 0;
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
