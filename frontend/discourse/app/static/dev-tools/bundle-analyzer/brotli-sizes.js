import workerUrl from "virtual:dynamic-chunk-url:discourse/workers/bundle-analyzer/brotli";

// Computes brotli sizes for every chunk when the analyzer opens, off the main
// thread. Results are cached in localStorage keyed by the digested file path
// (which embeds the content hash, so the cache is implicitly invalidated when a
// chunk changes), and the work is spread across a pool of workers. Started via a
// blob bootstrap like the media-optimization worker so it inherits the host CSP.
const CACHE_KEY = "discourse_bundle_analyzer_brotli";
const POOL_SIZE = Math.max(
  1,
  Math.min((navigator.hardwareConcurrency || 4) - 1, 8)
);

export default class BrotliSizes {
  workers = [];

  constructor(analysis) {
    this.analysis = analysis;
    this.cache = this.#readCache();

    // import.meta.url is this chunk's URL (assets/js/dev-tools-*.js); strip the
    // filename to get the assets root the chunk files are resolved against.
    const root = import.meta.url.replace(/assets\/js\/[^/]+$/, "");

    // Split into cache hits (applied up front) and work for the pool. This is
    // pure — no tracked mutation here, since we're inside the render that
    // constructed us; the actual updates happen in #begin a microtask later.
    this.cachedEntries = [];
    this.queue = [];
    for (const file of Object.keys(analysis.chunks)) {
      if (this.cache[file] != null) {
        this.cachedEntries.push([file, this.cache[file]]);
      } else {
        this.queue.push({ file, url: new URL(file, root).href });
      }
    }

    Promise.resolve().then(() => this.#begin());
  }

  teardown() {
    this.destroyed = true;
    for (const worker of this.workers) {
      worker.terminate();
    }
    this.workers = [];
    // Persist whatever was computed before the modal closed.
    this.#writeCache();
  }

  #begin() {
    if (this.destroyed) {
      return;
    }
    this.analysis.setBrotliMany(this.cachedEntries);
    if (this.queue.length === 0) {
      this.analysis.brotliComplete();
      return;
    }
    this.#startPool();
  }

  #startPool() {
    try {
      const blobUrl = URL.createObjectURL(
        new Blob([`import ${JSON.stringify(workerUrl)};`], {
          type: "text/javascript",
        })
      );
      try {
        const count = Math.min(POOL_SIZE, this.queue.length);
        for (let i = 0; i < count; i++) {
          const worker = new Worker(blobUrl, { type: "module" });
          worker.onmessage = (e) => this.#onResult(worker, e.data);
          this.workers.push(worker);
          this.#dispatch(worker);
        }
      } finally {
        URL.revokeObjectURL(blobUrl);
      }
    } catch {
      // Workers unsupported / blocked; fall back to whatever the cache had.
      this.#finish();
    }
  }

  #dispatch(worker) {
    const job = this.queue.shift();
    if (job) {
      worker.postMessage(job);
    } else {
      worker.terminate();
      this.workers = this.workers.filter((w) => w !== worker);
      if (this.workers.length === 0) {
        this.#finish();
      }
    }
  }

  #onResult(worker, { file, size }) {
    if (file != null && size != null) {
      this.analysis.setBrotli(file, size);
      this.cache[file] = size;
    }
    this.#dispatch(worker);
  }

  #finish() {
    this.#writeCache();
    this.analysis.brotliComplete();
  }

  #readCache() {
    try {
      return JSON.parse(window.localStorage.getItem(CACHE_KEY)) || {};
    } catch {
      return {};
    }
  }

  #writeCache() {
    // Keep only entries for chunks in the current build so the cache stays
    // bounded (stale hashes from previous builds are dropped).
    const kept = {};
    for (const file of Object.keys(this.analysis.chunks)) {
      if (this.cache[file] != null) {
        kept[file] = this.cache[file];
      }
    }
    try {
      window.localStorage.setItem(CACHE_KEY, JSON.stringify(kept));
    } catch {
      // Quota exceeded / unavailable — non-fatal, sizes were still computed.
    }
  }
}
