import { tracked } from "@glimmer/tracking";
import toMarkdown from "discourse/lib/to-markdown";

export default class QuoteState {
  @tracked postId = null;
  @tracked buffer = "";
  @tracked opts = null;

  #selectedHtml = null;
  #markdownPromise = null;

  selected(postId, buffer, opts, selectedHtml) {
    this.postId = postId;
    this.buffer = buffer;
    this.opts = opts;
    this.#selectedHtml = selectedHtml;
    this.#markdownPromise = null;
  }

  async markdown() {
    if (!this.#selectedHtml) {
      return this.buffer;
    }

    if (!this.#markdownPromise) {
      this.#markdownPromise = toMarkdown(this.#selectedHtml).then(
        (result) => result || this.buffer
      );
    }

    return this.#markdownPromise;
  }

  clear() {
    this.buffer = "";
    this.postId = null;
    this.opts = null;
    this.#selectedHtml = null;
    this.#markdownPromise = null;
  }
}
