import { isTesting } from "discourse/lib/environment";

const TEST_KEY_PREFIX = "__test_";

/**
 * @type {Storage}
 */
let safeSessionStorage;

try {
  safeSessionStorage = sessionStorage;
  if (sessionStorage["disableSessionStorage"] === "true") {
    safeSessionStorage = null;
  } else {
    // makes sure we can write to the session storage
    safeSessionStorage["safeSessionStorage"] = true;
  }
} catch {
  // session storage disabled
  safeSessionStorage = null;
}

export default class SessionStore {
  context = null;

  constructor(ctx) {
    this.context = isTesting() ? `${TEST_KEY_PREFIX}${ctx}` : ctx;
  }

  abandonLocal() {
    return this.removeKeys();
  }

  removeKeys(predicate = () => true) {
    if (!safeSessionStorage) {
      return;
    }

    let i = safeSessionStorage.length - 1;

    while (i >= 0) {
      let k = safeSessionStorage.key(i);
      let v = safeSessionStorage.getItem(k);
      try {
        v = JSON.parse(v);
      } catch {}

      if (
        k.substring(0, this.context.length) === this.context &&
        predicate(k, v)
      ) {
        safeSessionStorage.removeItem(k);
      }
      i--;
    }

    return true;
  }

  remove(key) {
    if (!safeSessionStorage) {
      return;
    }

    return safeSessionStorage.removeItem(this.context + key);
  }

  get(key) {
    if (!safeSessionStorage) {
      return null;
    }

    return safeSessionStorage.getItem(this.context + key);
  }

  set(opts) {
    if (!safeSessionStorage) {
      return false;
    }

    safeSessionStorage.setItem(this.context + opts.key, opts.value);
  }

  setObject(opts) {
    this.set({ key: opts.key, value: JSON.stringify(opts.value) });
  }

  getInt(key, def) {
    if (!def) {
      def = 0;
    }

    if (!safeSessionStorage) {
      return def;
    }

    const result = parseInt(this.get(key), 10);
    if (!isFinite(result)) {
      return def;
    }

    return result;
  }

  getObject(key) {
    if (!safeSessionStorage) {
      return null;
    }

    let v = safeSessionStorage.getItem(this.context + key);
    if (v === null) {
      return null;
    }

    try {
      v = JSON.parse(v);
    } catch {}

    return v;
  }
}

// API compatibility with `sessionStorage`
SessionStore.prototype.getItem = SessionStore.prototype.get;
SessionStore.prototype.removeItem = SessionStore.prototype.remove;
SessionStore.prototype.setItem = function (key, value) {
  this.set({ key, value });
};
