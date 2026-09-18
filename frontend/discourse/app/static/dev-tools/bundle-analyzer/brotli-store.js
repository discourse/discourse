import { tracked } from "@glimmer/tracking";

// Brotli sizes are computed in the browser (see brotli-sizes.js) and land here
// incrementally; tracked so the UI re-renders as each chunk is measured.
//
// A subclass supplies the `chunks` it covers, `urlFor` to fetch one, and a cache
// key of its own — two reports sharing a key would prune each other's entries.
export default class BrotliStore {
  @tracked brotli = new Map();
  @tracked brotliDone = false;

  get chunkCount() {
    return Object.keys(this.chunks).length;
  }

  get brotliCount() {
    return this.brotli.size;
  }

  setBrotli(file, size) {
    const next = new Map(this.brotli);
    next.set(file, size);
    this.brotli = next;
  }

  setBrotliMany(entries) {
    if (!entries.length) {
      return;
    }
    const next = new Map(this.brotli);
    for (const [file, size] of entries) {
      next.set(file, size);
    }
    this.brotli = next;
  }

  brotliComplete() {
    this.brotliDone = true;
  }

  brotliOf(file) {
    return this.brotli.get(file);
  }

  totals(files) {
    let raw = 0;
    let brotli = 0;
    // The brotli total is only meaningful once every chunk in the set has been
    // measured; until then the caller should show "…" rather than a low sum.
    let brotliReady = true;
    for (const f of files) {
      raw += this.chunks[f].rawSize;
      const b = this.brotli.get(f);
      if (b == null) {
        brotliReady = false;
      } else {
        brotli += b;
      }
    }
    return { files: files.size ?? files.length, raw, brotli, brotliReady };
  }
}
