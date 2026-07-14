import { tracked } from "@glimmer/tracking";
import { waitForPromise } from "@ember/test-waiters";
import toMarkdown from "discourse/lib/to-markdown";

export default class QuoteState {
  @tracked postId = null;

  #opts = null;
  #selectedHtml = null;
  #cookedHtml = null;
  #markdownPromise = null;

  get buffer() {
    if (!this.#selectedHtml) {
      return "";
    }
    // `<template>.content` is an inert DocumentFragment — no image/iframe fetches.
    const template = document.createElement("template");
    template.innerHTML = this.#selectedHtml;
    return template.content.textContent ?? "";
  }

  get opts() {
    return this.#opts;
  }

  // The `plainText` arg is accepted but unused; `buffer` now derives plaintext
  // from `selectedHtml`. The slot is kept to preserve the legacy arg shape.
  selected(postId, _plainText, opts, selectedHtml, cookedHtml) {
    this.postId = postId;
    this.#opts = opts;
    this.#selectedHtml = selectedHtml;
    this.#cookedHtml = cookedHtml;
    this.#markdownPromise = null;
  }

  async markdown() {
    if (!this.#selectedHtml) {
      return { markdown: this.buffer, opts: { ...this.#opts } };
    }

    if (!this.#markdownPromise) {
      this.#markdownPromise = waitForPromise(this.#computeMarkdown());
    }

    // Snapshot opts before the await so a concurrent selected() call cannot
    // pair our markdown with a later selection's attribution.
    const opts = this.#opts;
    const result = await this.#markdownPromise;

    return {
      markdown: result.markdown,
      opts: { ...opts, full: result.full },
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
        markdown: selectedMd || this.buffer,
        full: !!(cookedMd && selectedMd === cookedMd),
      };
    } catch {
      return { markdown: this.buffer, full: false };
    }
  }

  copyFrom(other) {
    this.selected(
      other.postId,
      null,
      other.#opts,
      other.#selectedHtml,
      other.#cookedHtml
    );
  }

  clear() {
    this.postId = null;
    this.#opts = null;
    this.#selectedHtml = null;
    this.#cookedHtml = null;
    this.#markdownPromise = null;
  }
}
