import Service from "@ember/service";

export default class AppEvents extends Service {
  #listeners = new Map();

  constructor() {
    super(...arguments);

    // A hack because we don't make `current user` properly via container in testing mode
    if (this.currentUser) {
      this.currentUser.appEvents = this;
    }
  }

  on(name, target, method, { once = false } = {}) {
    const listeners = this.#listeners.get(name) || [];

    if (typeof target !== "object") {
      method = target;
      target = globalThis;
    }

    listeners.push({
      target,
      method,
      once,
    });

    this.#listeners.set(name, listeners);

    return this;
  }

  one(name, target, method) {
    return this.on(name, target, method, { once: true });
  }

  trigger(name, ...args) {
    const listeners = this.#listeners.get(name);
    if (!listeners) {
      return;
    }

    for (const { target, method, once } of listeners) {
      let resolvedMethod = method;

      if (typeof method === "string") {
        resolvedMethod = target[method];
      }

      const type = typeof resolvedMethod;
      if (type === "function") {
        resolvedMethod.apply(target, args);
      } else if (type === "object") {
        resolvedMethod.perform(args);
      } else {
        throw new Error(`No method ${method} on ${target}`);
      }

      if (once) {
        this.off(name, target, method);
      }
    }

    return this;
  }

  off(name, target, method) {
    const listeners = this.#listeners.get(name);
    if (!listeners) {
      return;
    }

    const newListeners = listeners.filter(
      ({ _target, _method }) => target === _target && method === _method
    );
    this.#listeners.set(name, newListeners);

    return this;
  }

  has(eventName) {
    return this.#listeners.get(eventName)?.length > 0;
  }
}
