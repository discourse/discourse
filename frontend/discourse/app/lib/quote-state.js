import { tracked } from "@glimmer/tracking";
import { waitForPromise } from "@ember/test-waiters";
import toMarkdown from "discourse/lib/to-markdown";

export default class QuoteState {
  @tracked postId = null;
  @tracked buffer = "";
  @tracked opts = null;

  #selectedHtml = null;
  #cookedHtml = null;
  #markdownPromise = null;

  selected(postId, buffer, opts, selectedHtml, cookedHtml) {
    this.postId = postId;
    this.buffer = buffer;
    this.opts = opts;
    this.#selectedHtml = selectedHtml;
    this.#cookedHtml = cookedHtml;
    this.#markdownPromise = null;
  }

  async markdown() {
    if (!this.#selectedHtml) {
      return this.buffer;
    }

    if (!this.#markdownPromise) {
      this.#markdownPromise = waitForPromise(this.#computeMarkdown());
    }

    return this.#markdownPromise;
  }

  async #computeMarkdown() {
    const promises = [toMarkdown(this.#selectedHtml)];
    if (this.#cookedHtml) {
      promises.push(toMarkdown(this.#cookedHtml));
    }

    const [selectedMd, cookedMd] = await Promise.all(promises);

    if (cookedMd && selectedMd === cookedMd) {
      this.opts.full = true;
    }

    return selectedMd || this.buffer;
  }

  clear() {
    this.buffer = "";
    this.postId = null;
    this.opts = null;
    this.#selectedHtml = null;
    this.#cookedHtml = null;
    this.#markdownPromise = null;
  }
}
