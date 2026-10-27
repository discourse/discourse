import { tracked } from "@glimmer/tracking";

// Which of the report's chunks this browser has fetched, kept live so one
// loaded while the modal is open lights up too.
export default class LoadedChunks {
  @tracked files = new Set();

  constructor(chunks) {
    // Keyed by basename, which a content hash makes unique, so the host and path
    // a chunk was fetched from do not matter.
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
    const added = entries
      .map((entry) => this.byBasename.get(basename(entry.name)))
      .filter((file) => file && !this.files.has(file));

    if (added.length) {
      this.files = new Set([...this.files, ...added]);
    }
  }
}

function basename(url) {
  return url.split("?")[0].split("/").pop();
}
