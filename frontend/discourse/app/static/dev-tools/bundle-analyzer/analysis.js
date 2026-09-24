import { trustHTML } from "@ember/template";
import ChunkTotals from "./chunk-totals";

// The filename, without the directory it sits in.
export function fileName(file) {
  return file.replace(/^assets\/js\//, "");
}

// What to call a chunk on screen. A named one goes by its name, since the hash
// beside it distinguishes builds rather than chunks. An unnamed one has only
// its hash to tell it from its siblings, so it keeps it.
export function label(chunk) {
  if (!chunk) {
    return "";
  }
  return chunk.name && chunk.name !== ANONYMOUS
    ? chunk.name
    : fileName(chunk.file).replace(/\.digested\.js$/, "");
}

// What the build calls a chunk it cannot name after a module.
const ANONYMOUS = "chunk";

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

  // Topology: what a chunk pulls in synchronously, whatever the reader is
  // looking at. Baseline subtraction reads this, so "additional" keeps meaning
  // the same thing when the view narrows.
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

  // The part of that closure still in view.
  visibleClosure(file) {
    const closure = this.staticClosure(file);
    if (!this.view?.onlyLoaded) {
      return closure;
    }
    return new Set([...closure].filter((f) => this.includes(f)));
  }

  // Whether an entrypoint is worth a card, judged on exactly what the card
  // shows: the chunks it adds over `base`, still in view. A card measured on
  // its whole closure survives on chunks the baseline owns and then renders
  // empty. `base` is omitted for the card everything else measures against,
  // which owns its whole subtree.
  cardVisible(file, filter, base = null) {
    const closure = this.visibleClosure(file);
    const own = base ? [...closure].filter((f) => !base.has(f)) : [...closure];

    if (own.length === 0) {
      return false;
    }
    return !filter || own.some((f) => this.chunkMatches(f, filter));
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
