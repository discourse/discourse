import EmberObject from "@ember/object";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import deprecated from "discourse/lib/deprecated";

const EMBER_OBJECT_PROPERTIES = new Set([
  "constructor",
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

/**
 * ArrayLikeObject is an EmberObject that proxies array-like behavior to a TrackedArray,
 * while exposing additional properties and methods. Access array methods via `.content`.
 *
 * @class ArrayLikeObject
 * @extends EmberObject
 * @example
 *   const obj = ArrayLikeObject.create({ content: [1,2,3], foo: 'bar' });
 *   obj.content.push(4); // Use .content for array operations
 *   obj.foo // 'bar'
 *
 * Note: Must be instantiated via ArrayLikeObject.create().
 */
export default class ArrayLikeObject extends EmberObject {
  static #isConstructing = false; // to simulate a private constructor

  /**
   * Creates an instance of ArrayLikeObject. Must be used instead of `new`.
   *
   * @param {Object} attrs - Properties to set on the instance. `content` must be an array.
   * @returns {ArrayLikeObject}
   */
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

  /**
   * Constructor is private. Use ArrayLikeObject.create() instead.
   *
   * @param {Array} content - The array to wrap. Must be an array.
   * @throws {TypeError} If not called via .create or if content is not an array.
   * @private
   */
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

/**
 * Checks if a property is an EmberObject property or a custom instance property.
 *
 * @param {Object} instance - The object instance to check against.
 * @param {string|symbol} prop - The property name or symbol.
 * @returns {boolean} True if the property belongs to the instance, false otherwise.
 */
function isInstanceProperty(instance, prop) {
  return (
    Reflect.has(instance, prop) &&
    (EMBER_OBJECT_PROPERTIES.has(prop) || !ARRAY_PROPERTIES.has(prop))
  );
}

/**
 * Checks if a property is an Array property.
 *
 * @param {string|symbol} prop - The property name or symbol.
 * @returns {boolean} True if the property is an Array property, false otherwise.
 */
function isArrayProperty(prop) {
  return ARRAY_PROPERTIES.has(prop);
}

/**
 * Checks if a property is a numeric array index (string or number).
 * Accepts numeric strings or numbers (e.g. '0', 0, '12', 12).
 *
 * @param {string|number} prop - The property to check.
 * @returns {boolean} True if the property is a numeric index, false otherwise.
 */
function isNumericIndexProp(prop) {
  // Accepts numeric strings or numbers (e.g. '0', 0, '12', 12)
  return (
    (typeof prop === "string" && /^\d+$/.test(prop)) ||
    (typeof prop === "number" &&
      Number.isFinite(prop) &&
      Number.isInteger(prop))
  );
}

/**
 * Emits a deprecation warning for direct array property access.
 *
 * @param {string} instanceName - The name of the instance's constructor.
 * @param {string|number|symbol} prop - The property being accessed.
 * @param {boolean} [isIndex=false] - Whether the property is a numeric index.
 */
function warnArrayDeprecation(instanceName, prop, isIndex = false) {
  const propName = isIndex ? `[${prop}]` : `.${prop.toString()}`;
  deprecated(
    `Accessing \`(${instanceName} instance)${propName}\` directly is deprecated. ` +
      `Access the array directly via \`.content\` instead. ` +
      `For example, use \`(${instanceName} instance).content${propName}\` instead of \`(${instanceName} instance)${propName}\`.`,
    {
      id: "discourse.array-like-object.proxied-array",
    }
  );
}

/**
 * Creates a proxy that intercepts property access, forwarding instance properties to the ArrayLikeObject
 * and array properties to the underlying array.
 * Emits deprecation warnings for direct array property access.
 *
 * @param {ArrayLikeObject} instance - The ArrayLikeObject instance.
 * @param {TrackedArray} trackedItems - The underlying tracked array.
 * @returns {Proxy} Proxy object that combines instance and array behaviors.
 */
function createProxy(instance, trackedItems) {
  const instanceName = instance.constructor.name;

  return new Proxy(trackedItems, {
    get(target, prop, receiver) {
      if (prop === "content") {
        return target;
      }

      if (isInstanceProperty(instance, prop)) {
        return Reflect.get(instance, prop, receiver);
      }

      if (isArrayProperty(prop) || isNumericIndexProp(prop)) {
        warnArrayDeprecation(instanceName, prop, isNumericIndexProp(prop));
      }

      return Reflect.get(target, prop, receiver);
    },

    set(target, prop, value, receiver) {
      if (prop === "content") {
        throw new Error(
          `You cannot override the content property of an ${instanceName}, mutate the array instead.`
        );
      }

      if (isInstanceProperty(instance, prop)) {
        return Reflect.set(instance, prop, value, receiver);
      }

      if (isArrayProperty(prop) || isNumericIndexProp(prop)) {
        warnArrayDeprecation(instanceName, prop, isNumericIndexProp(prop));
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
      if (isInstanceProperty(instance, prop)) {
        return Reflect.getOwnPropertyDescriptor(instance, prop);
      }
      return Reflect.getOwnPropertyDescriptor(target, prop);
    },
  });
}
