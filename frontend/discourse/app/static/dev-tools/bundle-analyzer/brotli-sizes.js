import workerUrl from "virtual:dynamic-chunk-url:discourse/workers/bundle-analyzer/brotli";

// Spins up the brotli worker when the analyzer opens, fetches + compresses every
// chunk off the main thread, and feeds the results back into the Analysis (which
// holds them reactively). Started via a blob bootstrap like the media-optimization
// worker so it inherits the host document CSP.
export default class BrotliSizes {
  constructor(analysis) {
    this.analysis = analysis;

    // import.meta.url is this chunk's URL (assets/js/dev-tools-*.js); strip the
    // filename to get the assets root the chunk files are resolved against.
    const root = import.meta.url.replace(/assets\/js\/[^/]+$/, "");
    const files = Object.keys(analysis.chunks).map((file) => ({
      file,
      url: new URL(file, root).href,
    }));

    try {
      const blobUrl = URL.createObjectURL(
        new Blob([`import ${JSON.stringify(workerUrl)};`], {
          type: "text/javascript",
        })
      );
      try {
        this.worker = new Worker(blobUrl, { type: "module" });
      } finally {
        URL.revokeObjectURL(blobUrl);
      }

      this.worker.onmessage = (e) => {
        const { file, size, done } = e.data;
        if (file != null && size != null) {
          this.analysis.setBrotli(file, size);
        }
        if (done) {
          this.analysis.brotliComplete();
        }
      };

      this.worker.postMessage({ files });
    } catch {
      // Workers unsupported / blocked; brotli sizes simply stay unknown and the
      // UI falls back to raw sizes.
      this.analysis.brotliComplete();
    }
  }

  teardown() {
    this.worker?.terminate();
  }
}
