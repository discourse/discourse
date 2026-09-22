// Totals over a set of chunks.
//
// A brotli size is whatever the build measured when it compressed the chunk.
// A report without them — a plugin build, which does not compress yet — totals
// its raw bytes and says the brotli figure is not ready, so a caller shows
// nothing rather than a number that is really a zero.
export default class ChunkTotals {
  // The browser's record of what it fetched, and the shared toggle saying
  // whether anything else counts. Both are assigned by whoever owns the view,
  // and every size below is filtered through them: a total that quietly
  // included chunks the reader asked to hide would answer a different question
  // from the rows underneath it.
  loaded = null;
  view = null;

  get chunkCount() {
    return this.visibleFiles.length;
  }

  get visibleFiles() {
    return Object.keys(this.chunks).filter((f) => this.includes(f));
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
