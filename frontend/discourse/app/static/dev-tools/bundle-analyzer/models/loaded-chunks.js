import { tracked } from "@glimmer/tracking";
import { basename, subscribeToFetchedResources } from "../fetched-resources.js";

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

    this.unsubscribe = subscribeToFetchedResources((names) => this.#add(names));
  }

  has(file) {
    return this.files.has(file);
  }

  teardown() {
    this.unsubscribe();
  }

  #add(names) {
    const added = names
      .map((name) => this.byBasename.get(name))
      .filter((file) => file && !this.files.has(file));

    if (added.length) {
      this.files = new Set([...this.files, ...added]);
    }
  }
}
