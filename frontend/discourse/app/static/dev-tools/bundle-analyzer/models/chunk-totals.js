import { cached } from "@glimmer/tracking";

// Totals over a set of chunks, counting only what the view admits.
export default class ChunkTotals {
  loaded = null;
  view = null;

  @cached
  get chunkCount() {
    return Object.keys(this.chunks).filter((f) => this.includes(f)).length;
  }

  // Independent of the view: what this page cost, whatever the reader narrowed to.
  @cached
  get loadedTotals() {
    return this.totals(
      Object.keys(this.chunks).filter((f) => this.loaded?.has(f))
    );
  }

  includes(file) {
    return !this.view?.onlyLoaded || !!this.loaded?.has(file);
  }

  brotliOf(file) {
    return this.chunks[file]?.brotliSize ?? undefined;
  }

  totals(files) {
    let count = 0;
    let raw = 0;
    let brotli = 0;
    let brotliReady = true;
    for (const f of files) {
      if (!this.includes(f)) {
        continue;
      }
      count++;
      raw += this.chunks[f].rawSize;
      const b = this.brotliOf(f);
      if (b == null) {
        brotliReady = false;
      } else {
        brotli += b;
      }
    }
    return { files: count, raw, brotli, brotliReady };
  }
}
