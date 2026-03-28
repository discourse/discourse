import Service from "@ember/service";

const MAX_ENTRIES = 15;
const TTL_MS = 10 * 60 * 1000; // 10 minutes

export default class NestedViewCacheService extends Service {
  _cache = new Map();
  _lastNavigationType = null;
  _popstateTime = null;

  constructor() {
    super(...arguments);

    if (window.navigation) {
      this._onNavigate = (e) => {
        this._lastNavigationType = e.navigationType;
      };
      window.navigation.addEventListener("navigate", this._onNavigate);
    }

    // Always listen for popstate as a fallback — the Navigation API's
    // navigate event may not fire in all environments (e.g. Playwright CDP).
    this._onPopstate = () => {
      this._popstateTime = Date.now();
    };
    window.addEventListener("popstate", this._onPopstate);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this._onNavigate) {
      window.navigation?.removeEventListener("navigate", this._onNavigate);
    }
    window.removeEventListener("popstate", this._onPopstate);
  }

  useNextTransition() {
    this._forceUseCache = true;
  }

  consumeTraversal() {
    if (this._forceUseCache) {
      this._forceUseCache = false;
      this._lastNavigationType = null;
      this._popstateTime = null;
      return true;
    }

    // Prefer Navigation API (explicit traversal type) when available
    if (this._lastNavigationType != null) {
      const result = this._lastNavigationType === "traverse";
      this._lastNavigationType = null;
      this._popstateTime = null;
      return result;
    }

    // Fallback: popstate fires for back/forward in all browsers
    if (this._popstateTime && Date.now() - this._popstateTime < 1000) {
      this._popstateTime = null;
      return true;
    }
    this._popstateTime = null;
    return false;
  }

  save(key, entry) {
    entry.timestamp = Date.now();
    this._cache.set(key, entry);
    this._evict();
  }

  get(key) {
    const entry = this._cache.get(key);
    if (!entry) {
      return null;
    }
    if (Date.now() - entry.timestamp > TTL_MS) {
      this._cache.delete(key);
      return null;
    }
    return entry;
  }

  remove(key) {
    this._cache.delete(key);
  }

  _evict() {
    const now = Date.now();
    for (const [k, v] of this._cache) {
      if (now - v.timestamp > TTL_MS) {
        this._cache.delete(k);
      }
    }

    if (this._cache.size > MAX_ENTRIES) {
      const entries = [...this._cache.entries()].sort(
        (a, b) => a[1].timestamp - b[1].timestamp
      );
      const toRemove = entries.length - MAX_ENTRIES;
      for (let i = 0; i < toRemove; i++) {
        this._cache.delete(entries[i][0]);
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
