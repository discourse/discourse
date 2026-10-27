/**
 * DEPRECATED: Do not use LegacyArrayLikeObject for new code.
 *
 * This class is intended ONLY for providing TrackedArray capabilities to support
 * already existing classes that previously used the ArrayProxy mixin. It should not
 * be used in new development.
 *
 * For new code, use a standard class with tracked properties and `@autoTrackedArray` for the content property.
 * Example:
 *
 * ```js
 * import { tracked } from '@glimmer/tracking';
 * import { autoTrackedArray } from "discourse/lib/tracked-tools";
 *
 * class MyArrayWrapper {
 *   @tracked someProp;
 *   @autoTrackedArray content = [];
 * }
 * ```
 *
 * This approach provides reactivity and array capabilities without legacy proxy patterns.
 */

import EmberObject from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import deprecated from "discourse/lib/deprecated";
import { isTrackedArray } from "discourse/lib/tracked-tools";

const EMBER_OBJECT_PROPERTIES = new Set<PropertyKey>([
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

const ARRAY_PROPERTIES = new Set<PropertyKey>(
  [
    ...Object.getOwnPropertyNames(Array.prototype),
    ...Object.getOwnPropertySymbols(Array.prototype),
  ] //.filter((prop) => !EMBER_OBJECT_PROPERTIES.has(prop))
);

/**
 * @deprecated
 *
 * LegacyArrayLikeObject is an EmberObject that proxies array-like behavior to a TrackedArray,
 * while exposing additional properties and methods. Access array methods via `.content`.
 *
 * Note: Must be instantiated via LegacyArrayLikeObject.create().
 *
 * @example
 * ```js
 * const obj = LegacyArrayLikeObject.create({ content: [1,2,3], foo: 'bar' });
 * obj.content.push(4); // Use .content for array operations
 * obj.foo // 'bar'
 * ```
 */
export default class LegacyArrayLikeObject<T = unknown> extends EmberObject {
  static #isConstructing = false; // to simulate a private constructor

  /**
   * Creates an instance of LegacyArrayLikeObject. Must be used instead of `new`.
   *
   * @param attrs - Properties applied after subclass fields initialize. `content` must be an array.
   */
  static create<M extends LegacyArrayLikeObject>(
    this: new (...args: never[]) => M,
    attrs?: Partial<M> & Record<string, unknown>
  ): M;

  static create(attrs: { content?: unknown[] } & Record<string, unknown> = {}) {
    LegacyArrayLikeObject.#isConstructing = true;

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

  /**
   * Emits a deprecation warning for direct array property access.
   *
   * @param instance - The instance of LegacyArrayLikeObject (or subclass) being accessed
   * @param prop - The property being accessed on the instance
   * @internal
   * @example
   * ```js
   * // Will warn about accessing array methods directly:
   * const obj = CustomArrayLike.create({ content: [1,2,3] });
   * obj[0]; // Triggers deprecation warning
   * obj.push(4); // Triggers deprecation warning
   *
   * // Should use content instead:
   * obj.content[0]; // Correct usage
   * obj.content.push(4); // Correct usage
   * ```
   */
  static warnArrayDeprecation(
    instance: LegacyArrayLikeObject,
    prop: PropertyKey
  ) {
    const instanceName = instance.constructor.name;
    const propName = isNumericIndexProp(prop)
      ? `[${prop}]`
      : `.${prop.toString()}`;

    deprecated(
      `Accessing \`(${instanceName} instance)${propName}\` directly is deprecated. ` +
        (instance.warnContext ? `${instance.warnContext}\n` : "\n") +
        `Access the array directly via \`.content\` instead. \n\n` +
        `For example, use \`(${instanceName} instance).content${propName}\` instead of \`(${instanceName} instance)${propName}\`.`,
      {
        id: "discourse.legacy-array-like-object.proxied-array",
      }
    );
  }

  /** The proxy supplies this array; replacing it throws. Mutate its elements instead. */
  declare readonly content: T[];

  #content: T[];

  /**
   * Constructor is private. Use LegacyArrayLikeObject.create() instead.
   *
   * @param content - The array to wrap. Must be an array.
   * @throws `TypeError` if not called via .create or if content is not an array.
   * @internal
   */
  constructor(content: T[] = []) {
    super();

    if (!LegacyArrayLikeObject.#isConstructing) {
      throw new TypeError(
        `${this.constructor.name} is not constructable. Use the static \`${this.constructor.name}.create()\` method instead.`
      );
    }
    LegacyArrayLikeObject.#isConstructing = false;

    // Validate inputs
    if (!Array.isArray(content)) {
      throw new TypeError(
        `${this.constructor.name}: \`.content\` must be an array`
      );
    }

    this.#content = isTrackedArray(content) ? content : trackedArray(content);

    return createProxy(this, this.#content);
  }

  /**
   * Context string to add to array access deprecation warnings.
   * To be overridden by subclasses to provide additional context.
   */
  get warnContext(): string | undefined {
    // to be overridden by subclasses
    return undefined;
  }
}

/**
 * Checks if a property is an EmberObject property or a custom instance property.
 *
 * @param instance - The object instance to check against.
 * @param prop - The property name or symbol.
 * @returns True if the property belongs to the instance, false otherwise.
 */
function isInstanceProperty(instance: object, prop: PropertyKey): boolean {
  return (
    Reflect.has(instance, prop) &&
    (EMBER_OBJECT_PROPERTIES.has(prop) || !ARRAY_PROPERTIES.has(prop))
  );
}

/**
 * Checks if a property is an Array property.
 *
 * @param prop - The property name or symbol.
 * @returns True if the property is an Array property, false otherwise.
 */
function isArrayProperty(prop: PropertyKey): boolean {
  return ARRAY_PROPERTIES.has(prop);
}

/**
 * Checks if a property is a numeric array index (string or number).
 * Accepts numeric strings or numbers (e.g. '0', 0, '12', 12).
 *
 * @param prop - The property to check.
 * @returns True if the property is a numeric index, false otherwise.
 */
function isNumericIndexProp(prop: PropertyKey): prop is string | number {
  // Accepts numeric strings or numbers (e.g. '0', 0, '12', 12)
  return (
    (typeof prop === "string" && /^\d+$/.test(prop)) ||
    (typeof prop === "number" &&
      Number.isFinite(prop) &&
      Number.isInteger(prop))
  );
}

/**
 * Creates a proxy that intercepts property access, forwarding instance properties to the LegacyArrayLikeObject
 * and array properties to the underlying array.
 * Emits deprecation warnings for direct array property access.
 *
 * @param instance - The LegacyArrayLikeObject instance.
 * @param trackedItems - The underlying tracked array.
 * @returns Proxy object that combines instance and array behaviors.
 */
function createProxy<T>(
  instance: LegacyArrayLikeObject<T>,
  trackedItems: T[]
): LegacyArrayLikeObject<T> {
  // The traps expose the instance's prototype and members over the array target.
  return new Proxy(trackedItems, {
    get(target, prop, receiver) {
      if (prop === "content") {
        return target;
      }

      if (isInstanceProperty(instance, prop)) {
        return Reflect.get(instance, prop, receiver);
      }

      if (isArrayProperty(prop) || isNumericIndexProp(prop)) {
        (
          instance.constructor as typeof LegacyArrayLikeObject
        ).warnArrayDeprecation(instance, prop);
      }

      return Reflect.get(target, prop, receiver);
    },

    set(target, prop, value, receiver) {
      if (prop === "content") {
        throw new Error(
          `${instance.constructor.name}: You cannot override the \`content\` property, mutate the array instead.`
        );
      }

      if (isInstanceProperty(instance, prop)) {
        return Reflect.set(instance, prop, value, receiver);
      }

      if (isArrayProperty(prop) || isNumericIndexProp(prop)) {
        (
          instance.constructor as typeof LegacyArrayLikeObject
        ).warnArrayDeprecation(instance, prop);
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
  }) as unknown as LegacyArrayLikeObject<T>;
}
