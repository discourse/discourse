import { TrackedArray } from "@ember-compat/tracked-built-ins";

export default class ArrayLikeObject {
  #items;

  constructor(items = [], properties = {}) {
    // Validate inputs
    if (!Array.isArray(items)) {
      throw new TypeError("items must be an array");
    }

    this.#items =
      items instanceof TrackedArray ? items : new TrackedArray(items);
    const proxy = createProxy(this, this.#items);

    // Validate properties before assignment
    if (properties && typeof properties === "object") {
      Object.keys(properties).forEach((key) => {
        proxy[key] = properties[key];
      });
    }

    return proxy;
  }
}

function createProxy(instance, trackedItems) {
  return new Proxy(trackedItems, {
    get(target, prop, receiver) {
      if (Reflect.has(instance, prop)) {
        return Reflect.get(instance, prop, receiver);
      }
      return Reflect.get(target, prop, receiver);
    },

    set(target, prop, value, receiver) {
      if (Reflect.has(instance, prop)) {
        return Reflect.set(instance, prop, value, receiver);
      }
      return Reflect.set(target, prop, value, receiver);
    },

    has(target, prop) {
      return Reflect.has(instance, prop) || Reflect.has(target, prop);
    },

    getPrototypeOf() {
      return instance.constructor.prototype;
    },

    ownKeys(target) {
      const instanceKeys = Reflect.ownKeys(instance);
      const targetKeys = Reflect.ownKeys(target);

      return [...new Set([...instanceKeys, ...targetKeys])];
    },

    defineProperty(target, prop, descriptor) {
      return Reflect.defineProperty(instance, prop, descriptor);
    },

    deleteProperty(target, prop) {
      return Reflect.deleteProperty(instance, prop);
    },

    getOwnPropertyDescriptor(target, prop) {
      if (Reflect.has(instance, prop)) {
        return Reflect.getOwnPropertyDescriptor(instance, prop);
      }
      return Reflect.getOwnPropertyDescriptor(target, prop);
    },
  });
}
