import Service from "@ember/service";

// Registry of rendered depth-0 root post elements (post_number → element).
// Decouples the controller and topic-timeline from each other's DOM: both
// previously called document.querySelectorAll(".nested-view__roots
// .nested-post.--depth-0") and re-read [data-post-number], which silently
// breaks if either component renames its classes.
//
// Populated by <NestedPost> at depth 0 on mount, cleared on teardown.
// Consumers can synchronously read elements (getElement / elementsInOrder)
// or wait for a specific post to render after a window-changing load
// (waitForElement → Promise<element>).
export default class NestedRootElementsService extends Service {
  #elements = new Map();
  #pendingResolvers = new Map();

  register(postNumber, element) {
    if (postNumber == null || !element) {
      return;
    }
    this.#elements.set(postNumber, element);

    const resolvers = this.#pendingResolvers.get(postNumber);
    if (resolvers) {
      this.#pendingResolvers.delete(postNumber);
      for (const resolve of resolvers) {
        resolve(element);
      }
    }
  }

  unregister(postNumber) {
    if (postNumber == null) {
      return;
    }
    this.#elements.delete(postNumber);
  }

  clear() {
    this.#elements.clear();
    // Reject pending waits so callers don't hang across topic changes.
    for (const resolvers of this.#pendingResolvers.values()) {
      for (const resolve of resolvers) {
        resolve(null);
      }
    }
    this.#pendingResolvers.clear();
  }

  getElement(postNumber) {
    const el = this.#elements.get(postNumber);
    return el?.isConnected ? el : null;
  }

  // DOM-order iteration. Insertion order matches mount order, which for
  // an append-only list is also DOM order — but loadPreviousRoots
  // prepends and the controller can mutate rootNodes wholesale, so we
  // sort by getBoundingClientRect().top to stay correct.
  elementsInOrder() {
    const connected = [];
    for (const [postNumber, el] of this.#elements) {
      if (el.isConnected) {
        connected.push({ postNumber, el, top: el.getBoundingClientRect().top });
      }
    }
    connected.sort((a, b) => a.top - b.top);
    return connected;
  }

  firstElement() {
    return this.elementsInOrder()[0]?.el ?? null;
  }

  // Resolves with the element once it registers, or immediately if
  // it's already there. Used after a non-contiguous jump so the
  // controller can scroll without an afterRender + rAF guess.
  waitForElement(postNumber) {
    const existing = this.getElement(postNumber);
    if (existing) {
      return Promise.resolve(existing);
    }
    return new Promise((resolve) => {
      const existing_ = this.#pendingResolvers.get(postNumber) ?? [];
      existing_.push(resolve);
      this.#pendingResolvers.set(postNumber, existing_);
    });
  }
}
