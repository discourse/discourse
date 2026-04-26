import Service from "@ember/service";

const MAX_ENTRIES = 15;
const TTL_MS = 10 * 60 * 1000; // 10 minutes

export default class NestedViewCacheService extends Service {
  #cache = new Map();
  #lastNavigationType = null;
  #popstateTime = null;
  #forceUseCache = false;
  #onNavigate = null;
  #onPopstate = null;

  constructor() {
    super(...arguments);

    if (window.navigation) {
      this.#onNavigate = (e) => {
        this.#lastNavigationType = e.navigationType;
      };
      window.navigation.addEventListener("navigate", this.#onNavigate);
    }

    // Always listen for popstate as a fallback — the Navigation API's
    // navigate event may not fire in all environments (e.g. Playwright CDP).
    this.#onPopstate = () => {
      this.#popstateTime = Date.now();
    };
    window.addEventListener("popstate", this.#onPopstate);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.#onNavigate) {
      window.navigation?.removeEventListener("navigate", this.#onNavigate);
    }
    window.removeEventListener("popstate", this.#onPopstate);
  }

  useNextTransition() {
    this.#forceUseCache = true;
  }

  consumeTraversal() {
    if (this.#forceUseCache) {
      this.#forceUseCache = false;
      this.#lastNavigationType = null;
      this.#popstateTime = null;
      return true;
    }

    // Prefer Navigation API (explicit traversal type) when available
    if (this.#lastNavigationType != null) {
      const result = this.#lastNavigationType === "traverse";
      this.#lastNavigationType = null;
      this.#popstateTime = null;
      return result;
    }

    // Fallback: popstate fires for back/forward in all browsers
    if (this.#popstateTime && Date.now() - this.#popstateTime < 1000) {
      this.#popstateTime = null;
      return true;
    }
    this.#popstateTime = null;
    return false;
  }

  save(key, entry) {
    entry.timestamp = Date.now();
    this.#cache.set(key, entry);
    this.#evict();
  }

  get(key) {
    const entry = this.#cache.get(key);
    if (!entry) {
      return null;
    }
    if (Date.now() - entry.timestamp > TTL_MS) {
      this.#cache.delete(key);
      return null;
    }
    return entry;
  }

  remove(key) {
    this.#cache.delete(key);
  }

  #evict() {
    const now = Date.now();
    for (const [k, v] of this.#cache) {
      if (now - v.timestamp > TTL_MS) {
        this.#cache.delete(k);
      }
    }

    if (this.#cache.size > MAX_ENTRIES) {
      const entries = [...this.#cache.entries()].sort(
        (a, b) => a[1].timestamp - b[1].timestamp
      );
      const toRemove = entries.length - MAX_ENTRIES;
      for (let i = 0; i < toRemove; i++) {
        this.#cache.delete(entries[i][0]);
      }
    }
  }

  buildKey(topicId, params) {
    const parts = [topicId];
    if (params.sort) {
      parts.push(`s=${params.sort}`);
    }
    if (params.post_number) {
      parts.push(`p=${params.post_number}`);
    }
    if (params.context != null) {
      parts.push(`c=${params.context}`);
    }
    return parts.join(":");
  }
}
