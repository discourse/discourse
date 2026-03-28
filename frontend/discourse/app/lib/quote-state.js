import { tracked } from "@glimmer/tracking";
import { waitForPromise } from "@ember/test-waiters";
import toMarkdown from "discourse/lib/to-markdown";

export default class QuoteState {
  @tracked postId = null;

  #buffer = "";
  #opts = null;
  #selectedHtml = null;
  #cookedHtml = null;
  #markdownPromise = null;

  get buffer() {
    return this.#buffer;
  }

  get opts() {
    return this.#opts;
  }

  selected(postId, buffer, opts, selectedHtml, cookedHtml) {
    this.postId = postId;
    this.#buffer = buffer;
    this.#opts = opts;
    this.#selectedHtml = selectedHtml;
    this.#cookedHtml = cookedHtml;
    this.#markdownPromise = null;
  }

  async markdown() {
    if (!this.#selectedHtml) {
      return { markdown: this.#buffer, opts: { ...this.#opts } };
    }

    if (!this.#markdownPromise) {
      this.#markdownPromise = waitForPromise(this.#computeMarkdown());
    }

    const result = await this.#markdownPromise;

    return {
      markdown: result.markdown,
      opts: { ...this.#opts, full: result.full },
    };
  }

  async #computeMarkdown() {
    try {
      const promises = [toMarkdown(this.#selectedHtml)];
      if (this.#cookedHtml) {
        promises.push(toMarkdown(this.#cookedHtml));
      }

      const [selectedMd, cookedMd] = await Promise.all(promises);

      return {
        markdown: selectedMd || this.#buffer,
        full: !!(cookedMd && selectedMd === cookedMd),
      };
    } catch {
      return { markdown: this.#buffer, full: false };
    }
  }

  clear() {
    this.#buffer = "";
    this.postId = null;
    this.#opts = null;
    this.#selectedHtml = null;
    this.#cookedHtml = null;
    this.#markdownPromise = null;
  }
}
