import Service from "@ember/service";
import { isTesting } from "discourse/lib/environment";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

const TEST_KEY_PREFIX = "__test_";
const DISCOURSE_PREFIX = "discourse_";

@disableImplicitInjections
export default class SessionStoreService extends Service {
  context = null;

  constructor(ctx = DISCOURSE_PREFIX) {
    super(...arguments);
    this.context = isTesting() ? `${TEST_KEY_PREFIX}${ctx}` : ctx;
  }

  abandonLocal() {
    return this.removeKeys();
  }

  removeKeys(predicate = () => true) {
    if (!sessionStorage) {
      return;
    }

    let i = sessionStorage.length - 1;

    while (i >= 0) {
      let k = sessionStorage.key(i);
      let v = sessionStorage.getItem(k);
      try {
        v = JSON.parse(v);
      } catch {}

      if (
        k.substring(0, this.context.length) === this.context &&
        predicate(k, v)
      ) {
        sessionStorage.removeItem(k);
      }
      i--;
    }

    return true;
  }

  remove(key) {
    if (!sessionStorage) {
      return;
    }

    return sessionStorage.removeItem(this.context + key);
  }

  get(key) {
    if (!sessionStorage) {
      return null;
    }

    return sessionStorage.getItem(this.context + key);
  }

  set(opts) {
    if (!sessionStorage) {
      return false;
    }

    sessionStorage.setItem(this.context + opts.key, opts.value);
  }

  setObject(opts) {
    this.set({ key: opts.key, value: JSON.stringify(opts.value) });
  }

  getInt(key, def) {
    if (!def) {
      def = 0;
    }

    if (!sessionStorage) {
      return def;
    }

    const result = parseInt(this.get(key), 10);
    if (!isFinite(result)) {
      return def;
    }

    return result;
  }

  getObject(key) {
    if (!sessionStorage) {
      return null;
    }

    let v = sessionStorage.getItem(this.context + key);
    if (v === null) {
      return null;
    }

    try {
      v = JSON.parse(v);
    } catch {}

    return v;
  }

  // API compatibility with `sessionStorage`
  getItem(key) {
    return this.get(key);
  }

  removeItem(key) {
    return this.remove(key);
  }

  setItem(key, value) {
    this.set({ key, value });
  }
}
