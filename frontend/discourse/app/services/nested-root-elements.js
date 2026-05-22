import Service from "@ember/service";

// Registry of rendered depth-0 root post elements (post_number → element).
// Populated by <NestedPost> at depth 0 on mount, cleared on teardown.
export default class NestedRootElementsService extends Service {
  #elements = new Map();
  #postNumbers = new WeakMap();
  #pendingResolvers = new Map();
  #subscribers = new Set();

  register(postNumber, element) {
    if (postNumber == null || !element) {
      return;
    }
    this.#elements.set(postNumber, element);
    this.#postNumbers.set(element, postNumber);

    const resolvers = this.#pendingResolvers.get(postNumber);
    if (resolvers) {
      this.#pendingResolvers.delete(postNumber);
      for (const resolve of resolvers) {
        resolve(element);
      }
    }

    this.#notify("register", postNumber, element);
  }

  unregister(postNumber) {
    if (postNumber == null) {
      return;
    }
    const el = this.#elements.get(postNumber);
    this.#elements.delete(postNumber);
    if (el) {
      this.#postNumbers.delete(el);
      this.#notify("unregister", postNumber, el);
    }
  }

  clear() {
    for (const [postNumber, el] of this.#elements) {
      this.#postNumbers.delete(el);
      this.#notify("unregister", postNumber, el);
    }
    this.#elements.clear();
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

  // Sorted by viewport top so prepended pages (loadPreviousRoots) report correctly.
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

  waitForElement(postNumber) {
    const existing = this.getElement(postNumber);
    if (existing) {
      return Promise.resolve(existing);
    }
    return new Promise((resolve) => {
      const resolvers = this.#pendingResolvers.get(postNumber) ?? [];
      resolvers.push(resolve);
      this.#pendingResolvers.set(postNumber, resolvers);
    });
  }

  elements() {
    return this.#elements.values();
  }

  postNumberFor(element) {
    return this.#postNumbers.get(element);
  }

  // Subscribe to register/unregister events. Returns an unsubscribe function.
  // Used by NestedTopicTimeline to keep its IntersectionObserver in sync as
  // roots are paginated in/out without polling the registry every scroll frame.
  subscribe(fn) {
    this.#subscribers.add(fn);
    return () => this.#subscribers.delete(fn);
  }

  #notify(type, postNumber, element) {
    for (const fn of this.#subscribers) {
      fn(type, postNumber, element);
    }
  }
}
