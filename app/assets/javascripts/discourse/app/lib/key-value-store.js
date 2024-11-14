import { isTesting } from "discourse-common/config/environment";

const TEST_KEY_PREFIX = "__test_";

// A simple key value store that uses LocalStorage
let safeLocalStorage;

try {
  safeLocalStorage = localStorage;
  if (localStorage["disableLocalStorage"] === "true") {
    safeLocalStorage = null;
  } else {
    // makes sure we can write to the local storage
    safeLocalStorage["safeLocalStorage"] = true;
  }
} catch {
  // local storage disabled
  safeLocalStorage = null;
}

export default class KeyValueStore {
  context = null;

  constructor(ctx) {
    this.context = isTesting() ? `${TEST_KEY_PREFIX}${ctx}` : ctx;
  }

  abandonLocal() {
    return this.removeKeys();
  }

  removeKeys(predicate = () => true) {
    if (!safeLocalStorage) {
      return;
    }

    let i = safeLocalStorage.length - 1;

    while (i >= 0) {
      let k = safeLocalStorage.key(i);
      let v = safeLocalStorage[k];
      try {
        v = JSON.parse(v);
      } catch {}

      if (
        k.substring(0, this.context.length) === this.context &&
        predicate(k, v)
      ) {
        safeLocalStorage.removeItem(k);
      }
      i--;
    }

    return true;
  }

  remove(key) {
    if (!safeLocalStorage) {
      return;
    }

    return safeLocalStorage.removeItem(this.context + key);
  }

  set(opts) {
    if (!safeLocalStorage) {
      return false;
    }

    safeLocalStorage[this.context + opts.key] = opts.value;
  }

  setObject(opts) {
    this.set({ key: opts.key, value: JSON.stringify(opts.value) });
  }

  get(key) {
    if (!safeLocalStorage) {
      return null;
    }
    return safeLocalStorage[this.context + key];
  }

  getInt(key, def) {
    if (!def) {
      def = 0;
    }

    if (!safeLocalStorage) {
      return def;
    }

    const result = parseInt(this.get(key), 10);
    if (!isFinite(result)) {
      return def;
    }

    return result;
  }

  getObject(key) {
    if (!safeLocalStorage) {
      return null;
    }

    try {
      return JSON.parse(safeLocalStorage[this.context + key]);
    } catch {}
  }
}

// API compatibility with `localStorage`
KeyValueStore.prototype.getItem = KeyValueStore.prototype.get;
KeyValueStore.prototype.removeItem = KeyValueStore.prototype.remove;
KeyValueStore.prototype.setItem = function (key, value) {
  this.set({ key, value });
};
