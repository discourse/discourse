/* eslint-disable no-console */
import Service from "@ember/service";
import { registerDestructor } from "@ember/destroyable";
import { DEBUG } from "@glimmer/env";

export default class AppEvents extends Service {
  #listeners = new Map();
  #usage = new Map();

  constructor() {
    super(...arguments);

    // A hack because we don't make `current user` properly via container in testing mode
    if (this.currentUser) {
      this.currentUser.appEvents = this;
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);

    if (DEBUG) {
      setTimeout(() => {
        if (this.#usage.size > 0) {
          console.log("Leftover app-events listeners:");
          for (const [name, count] of this.#usage) {
            console.log(name, count);
          }

          this.#usage.clear();
          this.#listeners.clear();
        }
      }, 1);
    } else {
      this.#listeners.clear();
    }
  }

  on(name, target, method, { once = false } = {}) {
    const listeners = this.#listeners.get(name) || [];

    if (typeof target === "object") {
      registerDestructor(target, () => this.off(name, target, method));
    } else {
      if (DEBUG) {
        console.log(
          `Called appEvents.on("${name}", ...) without a target argument`
        );
      }

      method = target;
      target = globalThis;
    }

    listeners.push({ target, method, once });
    this.#listeners.set(name, listeners);

    const count = this.#usage.get(name) || 0;
    this.#usage.set(name, count + 1);

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

      if (typeof resolvedMethod === "function") {
        resolvedMethod.apply(target, args);
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
      (listener) => !(target === listener.target && method === listener.method)
    );

    if (listeners.length === newListeners.length) {
      console.warn(
        "Trying to remove an app-event listener that doesn't exist:",
        name
      );
    }

    if (newListeners.length > 0) {
      this.#listeners.set(name, newListeners);
      this.#usage.set(name, newListeners.length);
    } else {
      this.#listeners.delete(name);
      this.#usage.delete(name);
    }

    return this;
  }

  has(eventName) {
    return this.#listeners.get(eventName)?.length > 0;
  }
}
