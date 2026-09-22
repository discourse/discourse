// Totals over a set of chunks.
//
// A brotli size is whatever the build measured when it compressed the chunk.
// A report without them — a plugin build, which does not compress yet — totals
// its raw bytes and says the brotli figure is not ready, so a caller shows
// nothing rather than a number that is really a zero.
export default class ChunkTotals {
  get chunkCount() {
    return Object.keys(this.chunks).length;
  }

  brotliOf(file) {
    return this.chunks[file]?.brotliSize ?? undefined;
  }

  totals(files) {
    let raw = 0;
    let brotli = 0;
    let brotliReady = true;
    for (const f of files) {
      raw += this.chunks[f].rawSize;
      const b = this.brotliOf(f);
      if (b == null) {
        brotliReady = false;
      } else {
        brotli += b;
      }
    }
    return { files: files.size ?? files.length, raw, brotli, brotliReady };
  }
}
