import { TrackedArray } from "@ember-compat/tracked-built-ins";

export default class ArrayModel {
  #items;

  constructor(items = [], properties = {}) {
    // Validate inputs
    if (!Array.isArray(items) && !items[Symbol.iterator]) {
      throw new TypeError("items must be array-like");
    }

    this.#items = new TrackedArray(items);

    const ownKeys = buildOwnKeysSet(this, this.constructor.prototype);
    const proxy = createProxy(this, this.#items, ownKeys);

    // Validate properties before assignment
    if (properties && typeof properties === "object") {
      Object.keys(properties).forEach((key) => {
        proxy[key] = properties[key];
      });
    }

    return proxy;
  }
}

function buildOwnKeysSet(instance, stopAtPrototype) {
  const ownKeys = new Set();
  let proto = instance.constructor.prototype;

  while (proto && proto !== Object.prototype) {
    [
      ...Object.getOwnPropertyNames(proto),
      ...Object.getOwnPropertySymbols(proto),
    ].forEach((item) => {
      // Skip constructor and prototype properties
      if (item !== "constructor" && item !== "prototype") {
        ownKeys.add(item);
      }
    });

    if (proto === stopAtPrototype) {
      break;
    }

    proto = Object.getPrototypeOf(proto);
  }

  return ownKeys;
}

function createProxy(instance, trackedItems, ownKeys) {
  return new Proxy(trackedItems, {
    get(target, prop, receiver) {
      if (ownKeys.has(prop)) {
        return Reflect.get(instance, prop, receiver);
      }
      return Reflect.get(target, prop, receiver);
    },

    set(target, prop, value, receiver) {
      if (ownKeys.has(prop)) {
        return Reflect.set(instance, prop, value, receiver);
      }
      return Reflect.set(target, prop, value, receiver);
    },

    has(target, prop) {
      return ownKeys.has(prop) || Reflect.has(target, prop);
    },

    getPrototypeOf() {
      return instance.constructor.prototype;
    },

    ownKeys(target) {
      const targetKeys = Reflect.ownKeys(target);
      const instanceKeys = Array.from(ownKeys);

      return [...new Set([...targetKeys, ...instanceKeys])];
    },

    defineProperty(target, prop, descriptor) {
      if (ownKeys.has(prop)) {
        return Reflect.defineProperty(instance, prop, descriptor);
      }
      return Reflect.defineProperty(target, prop, descriptor);
    },

    deleteProperty(target, prop) {
      if (ownKeys.has(prop)) {
        return Reflect.deleteProperty(instance, prop);
      }
      return Reflect.deleteProperty(target, prop);
    },

    getOwnPropertyDescriptor(target, prop) {
      if (ownKeys.has(prop)) {
        return Reflect.getOwnPropertyDescriptor(instance, prop);
      }
      return Reflect.getOwnPropertyDescriptor(target, prop);
    },
  });
}
