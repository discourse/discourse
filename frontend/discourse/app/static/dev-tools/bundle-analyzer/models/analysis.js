import { trustHTML } from "@ember/template";
import ChunkTotals from "./chunk-totals.js";

export function fileName(file) {
  return file.replace(/^assets\/js\//, "");
}

export function label(chunk) {
  if (!chunk) {
    return "";
  }
  return chunk.name && chunk.name !== ANONYMOUS
    ? chunk.name
    : fileName(chunk.file).replace(/\.digested\.js$/, "");
}

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

export function sizeOrDash(size) {
  return size == null ? "—" : fmt(size);
}

// A set holding a chunk the build did not compress reads as a dash, rather than
// a total counting that chunk as zero.
export function brotliLabel(totals) {
  return sizeOrDash(totals.brotliReady ? totals.brotli : null);
}

export function barWidth(length, max) {
  return trustHTML(`width:${Math.max(2, (length / max) * 100)}%`);
}

export function matches(text, filter) {
  return !filter || text.toLowerCase().includes(filter);
}

// Wraps the report JSON and answers the graph questions the UI asks of it.
export default class Analysis extends ChunkTotals {
  #closures = new Map();
  #matchCache = new Map();
  #matchFilter = null;
  #visible = new Map();
  #visibleKey = null;

  constructor(data) {
    super();
    this.chunks = data.chunks;
    this.entrypoints = data.entrypoints;
    this.dynamicEntrypoints = data.dynamicEntrypoints;
    this.usedByEntries = this.#computeUsedBy();
  }

  // Unfiltered, so baseline subtraction keeps its meaning when the view narrows.
  // Memoised: every card sizes and sorts itself by walking one of these.
  staticClosure(file) {
    let closure = this.#closures.get(file);
    if (!closure) {
      closure = new Set();
      this.#walk(file, closure);
      this.#closures.set(file, closure);
    }
    return closure;
  }

  // Every card on screen asks about the chunks it shares with the others, so
  // both answers are kept until the question changes.
  chunkMatches(file, filter) {
    if (!filter) {
      return true;
    }

    if (this.#matchFilter !== filter) {
      this.#matchFilter = filter;
      this.#matchCache.clear();
    }

    if (!this.#matchCache.has(file)) {
      const c = this.chunks[file];
      this.#matchCache.set(
        file,
        !!c &&
          (matches(file, filter) ||
            matches(c.name, filter) ||
            c.modules.some((m) => matches(m.id, filter)))
      );
    }

    return this.#matchCache.get(file);
  }

  visibleClosure(file) {
    if (!this.view?.onlyLoaded) {
      return this.staticClosure(file);
    }

    // Keyed on how much the browser has loaded, which only ever grows, so a
    // chunk arriving while the modal is open still reaches the rows.
    const key = this.loaded?.files.size ?? 0;
    if (this.#visibleKey !== key) {
      this.#visibleKey = key;
      this.#visible.clear();
    }

    if (!this.#visible.has(file)) {
      this.#visible.set(
        file,
        new Set([...this.staticClosure(file)].filter((f) => this.includes(f)))
      );
    }

    return this.#visible.get(file);
  }

  // Judged on what the card shows rather than its whole closure, which would
  // keep a card alive on baseline chunks and then render it empty.
  cardVisible(file, filter, base = null) {
    const closure = this.visibleClosure(file);
    const own = base ? [...closure].filter((f) => !base.has(f)) : [...closure];

    if (own.length === 0) {
      return false;
    }
    return !filter || own.some((f) => this.chunkMatches(f, filter));
  }

  sortSize(file) {
    const c = this.chunks[file];
    if (!c) {
      return 0;
    }
    return this.brotliOf(file) ?? c.rawSize;
  }

  #walk(file, set) {
    if (set.has(file) || !this.chunks[file]) {
      return;
    }
    set.add(file);
    for (const dep of this.chunks[file].imports) {
      this.#walk(dep, set);
    }
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
