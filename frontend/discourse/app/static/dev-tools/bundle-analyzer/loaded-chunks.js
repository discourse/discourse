import { tracked } from "@glimmer/tracking";

// Tracks which of the report's chunk files the browser has actually fetched
// this session, via the Resource Timing API. Covers both the initial <script>
// tags and anything pulled in later by import(). Stays live while open through
// a PerformanceObserver, so chunks loaded after the modal opens light up too.
export default class LoadedChunks {
  @tracked files = new Set();

  constructor(chunks) {
    // Chunk filenames carry a content hash, so the basename is unique and
    // matches regardless of CDN host / path prefix on the fetched URL.
    this.byBasename = new Map();
    for (const file of Object.keys(chunks)) {
      this.byBasename.set(basename(file), file);
    }

    try {
      this.observer = new PerformanceObserver((list) =>
        this.#add(list.getEntries())
      );
      // Buffered, so this replays what the page already fetched.
      this.observer.observe({ type: "resource", buffered: true });
    } catch {
      // PerformanceObserver unsupported; take the one reading available.
      this.#add(performance.getEntriesByType("resource"));
    }
  }

  has(file) {
    return this.files.has(file);
  }

  teardown() {
    this.observer?.disconnect();
  }

  #add(entries) {
    let next;
    for (const entry of entries) {
      const file = this.byBasename.get(basename(entry.name));
      if (file && !this.files.has(file)) {
        next ??= new Set(this.files);
        next.add(file);
      }
    }
    if (next) {
      this.files = next;
    }
  }
}

function basename(url) {
  return url.split("?")[0].split("/").pop();
}
