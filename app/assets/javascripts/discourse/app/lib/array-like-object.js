import EmberObject from "@ember/object";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import deprecated from "discourse/lib/deprecated";

const EMBER_OBJECT_PROPERTIES = new Set([
  "addObserver",
  "cacheFor",
  "decrementProperty",
  "destroy",
  "get",
  "getProperties",
  "incrementProperty",
  "init",
  "notifyPropertyChange",
  "removeObserver",
  "set",
  "setProperties",
  "toString",
  "toggleProperty",
  "willDestroy",
  "concatenatedProperties",
  "isDestroyed",
  "isDestroying",
  "mergedProperties",
]);
const ARRAY_PROPERTIES = new Set(
  [
    ...Object.getOwnPropertyNames(Array.prototype),
    ...Object.getOwnPropertySymbols(Array.prototype),
  ] //.filter((prop) => !EMBER_OBJECT_PROPERTIES.has(prop))
);

export default class ArrayLikeObject extends EmberObject {
  static #isConstructing = false; // to simulate a private constructor

  static create(attrs = {}) {
    ArrayLikeObject.#isConstructing = true;

    const { content, ...properties } = attrs;
    const object = new this(content);

    // on subclasses the fields are initialized after the constructor of the base class
    // has run with the super() clause.
    // See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Classes/constructor
    // Because of this, to prevent the proxy from getting confused and saving field properties into
    // the underlying TrackedArray, we need to set the properties after the instance has been created.
    object.setProperties(properties);

    return object;
  }

  #content;

  constructor(content = []) {
    super();

    if (!ArrayLikeObject.#isConstructing) {
      throw new TypeError(
        `${this.constructor.name} is not constructable. Use the static \`${this.constructor.name}.create()\` method instead.`
      );
    }
    ArrayLikeObject.#isConstructing = false;

    // Validate inputs
    if (!Array.isArray(content)) {
      throw new TypeError(
        `${this.constructor.name}: \`.content\` must be an array`
      );
    }

    this.#content =
      content instanceof TrackedArray ? content : new TrackedArray(content);

    return createProxy(this, this.#content);
  }
}

function createProxy(instance, trackedItems) {
  const instanceName = instance.constructor.name;

  return new Proxy(trackedItems, {
    get(target, prop, receiver) {
      if (prop === "content") {
        return target;
      }

      if (
        Reflect.has(instance, prop) &&
        (EMBER_OBJECT_PROPERTIES.has(prop) || !ARRAY_PROPERTIES.has(prop))
      ) {
        return Reflect.get(instance, prop, receiver);
      }

      if (
        ARRAY_PROPERTIES.has(prop) ||
        (Number.isFinite(prop) && Number.isInteger(Number(prop)))
      ) {
        deprecated(
          `Accessing \`${prop.toString()}\` directly on an ${instanceName} is deprecated. Access the array directly via \`${instanceName}.content\` instead. For example, \`${instanceName}.content.map()\` instead of \`${instanceName}.map()\`.`,
          {
            id: "discourse.array-like-object.proxied-array",
          }
        );
      }

      return Reflect.get(target, prop, receiver);
    },

    set(target, prop, value, receiver) {
      if (prop === "content") {
        throw new Error(
          `You cannot override the content property of an ${instanceName}, mutate the array instead.`
        );
      }

      if (
        Reflect.has(instance, prop) &&
        (EMBER_OBJECT_PROPERTIES.has(prop) || !ARRAY_PROPERTIES.has(prop))
      ) {
        return Reflect.set(instance, prop, value, receiver);
      }

      if (
        ARRAY_PROPERTIES.has(prop) ||
        (Number.isFinite(prop) && Number.isInteger(Number(prop)))
      ) {
        deprecated(
          `Accessing \`${prop.toString()}\` directly on an ${instanceName} is deprecated. Access the array directly via \`${instanceName}.content\` instead. For example, \`${instanceName}.content.map()\` instead of \`${instanceName}.map()\`.`,
          {
            id: "discourse.array-like-object.proxied-array",
          }
        );
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
      if (
        Reflect.has(instance, prop) &&
        (EMBER_OBJECT_PROPERTIES.has(prop) || !ARRAY_PROPERTIES.has(prop))
      ) {
        return Reflect.getOwnPropertyDescriptor(instance, prop);
      }
      return Reflect.getOwnPropertyDescriptor(target, prop);
    },
  });
}
