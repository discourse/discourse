import { setCustomTagFor } from "@glimmer/manager";
import { tracked } from "@glimmer/tracking";
import {
  dirtyTagFor,
  tagFor,
  track,
  type UpdatableTag,
  updateTag,
} from "@glimmer/validator";
import { meta as metaFor, peekMeta } from "@ember/-internals/meta";
import { TrackedDescriptor } from "@ember/-internals/metal";
import {
  trackedArray,
  trackedObject,
  trackedSet,
} from "@ember/reactive/collections";
import { next } from "@ember/runloop";

/** Babel's legacy field descriptor, with values kept unknown until validated. */
interface FieldDescriptor<Value = unknown> {
  initializer?: (this: object) => Value;
  get?: (this: object) => Value;
  set?: (this: object, value: Value) => void;
  value?: Value;
  writable?: boolean;
  enumerable?: boolean;
  configurable?: boolean;
  isTracked?: boolean;
}

/** Accessors returned by the legacy tracked field decorators. */
interface TrackedAccessor<Value = unknown> {
  get: (this: object) => Value;
  set: (this: object, value: Value) => void;
}

/**
 * TODO(typescript-pending): Ember's descriptor overload permits undefined and
 * untyped accessors, and omits isTracked. Remove when it exposes the field
 * decorator's guaranteed accessors and preserves the initializer's value type.
 */
type TrackedFieldDecorator = <Value>(
  target: object,
  key: string,
  desc: FieldDescriptor<Value>
) => TrackedAccessor<Value>;

type ArrayValue = readonly unknown[] | null | undefined;

/**
 * Define a tracked property on an object without needing to use the `@tracked` decorator.
 * Useful when meta-programming the creation of properties on an object.
 *
 * This must be run before the property is first accessed, so it normally makes sense for
 * this to only be called from a constructor.
 */
export function defineTrackedProperty(
  target: object,
  key: string,
  value: unknown
): void {
  Object.defineProperty(
    target,
    key,
    (tracked as TrackedFieldDecorator)(target, key, { enumerable: true, value })
  );
}

/**
 * Creates a tracked object that bridges Ember's native autotracking system with
 * the classic `@computed` / `@discourseComputed` dependent key chain observation.
 *
 * Ember's native `trackedObject()` only dirties internal Cell tags on property set,
 * which are invisible to `@computed("obj.prop")` chains that use `tagFor()` from
 * `TRACKED_TAGS`. It also uses data descriptors on its Proxy target, which causes
 * Ember's `setupMandatorySetter` to install a mandatory setter that blocks all
 * subsequent direct property assignments.
 *
 * This wrapper:
 * 1. Registers `setCustomTagFor` so `tagForProperty()` bypasses `setupMandatorySetter`
 * 2. Intercepts `set` to also call `dirtyTagFor()` for classic chain tag invalidation
 *
 * @param obj - The object to wrap in a tracked proxy.
 * @returns A proxy that supports both native autotracking and classic `@computed` chains.
 */
export function trackedObjectWithComputedSupport<T extends object>(obj: T): T {
  const inner = trackedObject(obj);

  const outer = new Proxy(inner, {
    set(target, prop, value) {
      const result = Reflect.set(target, prop, value);
      dirtyTagFor(outer, prop);
      return result;
    },
  });

  setCustomTagFor(outer, (_obj, key) => tagFor(outer, key));

  return outer;
}

class ResettableTrackedState {
  @tracked currentValue: unknown;
  previousUpstreamValue: unknown;
}

function getOrCreateState(
  map: WeakMap<object, ResettableTrackedState>,
  instance: object
): ResettableTrackedState {
  let state = map.get(instance);
  if (!state) {
    state = new ResettableTrackedState();
    map.set(instance, state);
  }
  return state;
}

/**
 * @decorator
 *
 * Marks a field as tracked. Its initializer will be re-run whenever upstream state changes.
 *
 * @example
 *
 * ```js
 * class UserRenameForm {
 *   ⁣@resettableTracked fullName = this.args.fullName;
 *
 *   updateName(newName) {
 *     this.fullName = newName;
 *   }
 * }
 * ```
 *
 * `this.fullName` will be updated whenever `updateName()` is called, or there is a change to
 * `this.args.fullName`.
 *
 */
export function resettableTracked(prototype: object, key: string): void;
export function resettableTracked(
  prototype: object,
  key: string,
  descriptor: FieldDescriptor
): TrackedAccessor;
export function resettableTracked(
  prototype: object,
  key: string,
  descriptor?: FieldDescriptor
): TrackedAccessor {
  // Babel supplies the descriptor even though TypeScript checks fields with two arguments.
  // One WeakMap per-property-per-class. Keys are instances of the class
  const states = new WeakMap<object, ResettableTrackedState>();

  return {
    get(this: object) {
      const state = getOrCreateState(states, this);

      const upstreamValue = descriptor!.initializer?.call(this);

      if (upstreamValue !== state.previousUpstreamValue) {
        state.currentValue = upstreamValue;
        state.previousUpstreamValue = upstreamValue;
      }

      return state.currentValue;
    },

    set(this: object, value: unknown) {
      const state = getOrCreateState(states, this);
      state.currentValue = value;
    },
  };
}

/**
 * @decorator
 *
 * Same as `@tracked`, but skips notifying about updates if the value is unchanged. This introduces some
 * performance overhead, so should only be used where excessive downstream re-evaluations are a problem.
 *
 * @example
 *
 * ```js
 * class UserRenameForm {
 *   ⁣@dedupeTracked fullName;
 * }
 *
 * const form = new UserRenameForm();
 * form.fullName = "Alice"; // Downstream consumers will be notified
 * form.fullName = "Alice"; // Downstream consumers will not be re-notified
 * form.fullName = "Bob"; // Downstream consumers will be notified
 * ```
 *
 */
export function dedupeTracked(target: object, key: string): void;
export function dedupeTracked(
  target: object,
  key: string,
  desc: FieldDescriptor
): TrackedAccessor;
export function dedupeTracked(
  target: object,
  key: string,
  desc?: FieldDescriptor
): TrackedAccessor {
  // Babel supplies desc even though TypeScript checks fields with two arguments.
  const { initializer } = desc!;
  const { get, set } = (tracked as TrackedFieldDecorator)(target, key, desc!);

  const values = new WeakMap<object, unknown>();

  return {
    get(this: object) {
      if (!values.has(this)) {
        const value = initializer?.call(this);
        values.set(this, value);
        set.call(this, value);
      }

      return get.call(this);
    },

    set(this: object, value: unknown) {
      if (!values.has(this) || values.get(this) !== value) {
        values.set(this, value);
        set.call(this, value);
      }
    },
  };
}

export class DeferredTrackedSet<T = unknown> {
  #set: Set<T>;

  constructor(value?: Iterable<T> | null) {
    this.#set = trackedSet(value);
  }

  get size(): number {
    return this.#set.size;
  }

  get [Symbol.toStringTag](): string {
    return this.#set[Symbol.toStringTag];
  }

  has(value: T): boolean {
    return this.#set.has(value);
  }

  entries(): SetIterator<[T, T]> {
    return this.#set.entries();
  }

  keys(): SetIterator<T> {
    return this.#set.keys();
  }

  values(): SetIterator<T> {
    return this.#set.values();
  }

  forEach(fn: (value: T, value2: T, set: Set<T>) => void): void {
    return this.#set.forEach(fn);
  }

  [Symbol.iterator](): SetIterator<T> {
    return this.#set[Symbol.iterator]();
  }

  add(value: T): this {
    next(() => this.#set.add(value));
    return this;
  }

  delete(value: T): this {
    next(() => this.#set.delete(value));
    return this;
  }

  clear(): void {
    next(() => this.#set.clear());
  }
}

// Capture the prototype shared by all tracked arrays returned by Ember's
// trackedArray(). The constructor returns a Proxy whose getPrototypeOf trap
// yields this prototype, so isPrototypeOf can detect them without access
// to the (unexported) TrackedArray class.
const trackedArrayPrototype = Object.getPrototypeOf(trackedArray());

/**
 * Checks whether a value is a tracked array created by Ember's native
 * `trackedArray()` from `@ember/reactive/collections`.
 *
 * This does NOT detect instances of the legacy `TrackedArray` class from
 * `@ember-compat/tracked-built-ins`. Only arrays produced by Ember's
 * `trackedArray()` function share the prototype used for detection.
 *
 * @param value - The value to check.
 * @returns `true` if the value is a tracked array, `false` otherwise.
 */
export function isTrackedArray(value: unknown): value is unknown[] {
  return value != null && trackedArrayPrototype.isPrototypeOf(value);
}

/**
 * Converts a value to TrackedArray if needed and validates the type.
 *
 * @param value - Value to convert
 * @returns - Returns the value converted to TrackedArray if needed,
 *                                         or null/undefined if those values were passed
 * @throws Error if value is not an array, TrackedArray, null or undefined
 */
function ensureTrackedArray(
  value: unknown,
  propertyName: string
): unknown[] | null | undefined {
  if (typeof value === "undefined" || value === null) {
    return value;
  }

  if (isTrackedArray(value)) {
    return value;
  }

  if (Array.isArray(value)) {
    return trackedArray(value);
  }

  throw new Error(
    `[${propertyName}]: Expected an array, TrackedArray, null, or undefined, got ${typeof value}. Value received: ${value}`
  );
}

/**
 * @decorator
 * Same as `@tracked`, but initializes the value as a TrackedArray.
 *
 * @param target - The target object
 * @param key - The property key
 * @param desc - The property descriptor
 * @returns Modified property descriptor that wraps arrays in TrackedArray
 *
 * @example
 * ```js
 * class TodoList {
 *   @autoTrackedArray todos = ['Buy milk', 'Walk dog'];
 * }
 * ```
 */
export function autoTrackedArray<Key extends string>(
  target: { [Property in Key]?: ArrayValue },
  key: Key
): void;
export function autoTrackedArray(
  target: object,
  key: string,
  desc: FieldDescriptor<ArrayValue>
): TrackedAccessor<ArrayValue> & {
  enumerable: boolean;
  configurable: boolean;
  isTracked: boolean;
};
export function autoTrackedArray(
  target: object,
  key: string,
  desc?: FieldDescriptor<ArrayValue>
) {
  // Babel supplies desc even though TypeScript checks fields with two arguments.
  if (desc!.initializer) {
    const originalInitializer = desc!.initializer;
    desc!.initializer = function () {
      const initialValue = originalInitializer.apply(this);
      return ensureTrackedArray(initialValue, key);
    };
  }

  const { get, set } = (tracked as TrackedFieldDecorator)(target, key, {
    ...desc,
    enumerable: true,
    configurable: true,
    isTracked: true,
  });

  function autoTrackedArraySetter(this: object, value: unknown) {
    set.call(this, ensureTrackedArray(value, key));
  }

  // Bridge TrackedArray content changes to the classic computed property tag
  // system. Without this, @computed('prop') only invalidates on reference
  // changes (this.prop = newArray), not on content mutations like push().
  //
  // This manually implements the same bridging that @dependentKeyCompat does
  // (we can't use @dependentKeyCompat directly because it rejects properties
  // that are already @tracked). The getter captures the TrackedArray's
  // collection tag via track(), then updates tagFor(obj, key) so that
  // @computed properties watching this key see content changes.
  function autoTrackedArrayGetter(this: object) {
    // Read the value outside track() to avoid a tag cycle. get.call(this)
    // consumes the property's own tag (tagFor(this, key)) via the tracked
    // storage. If we captured that inside track() and then called updateTag
    // on the same tag, it would create a self-referential cycle.
    const value = get.call(this);

    if (value != null) {
      // Only capture the TrackedArray's collection tag. TrackedArray's Proxy
      // get trap for 'length' calls getValue(collection), registering the
      // collection storage as an autotracking dependency. All mutations
      // (push, pop, splice, etc.) dirty this same storage via
      // setValue(collection, null).
      const propertyTag = tagFor(this, key);
      const collectionTag = track(() => value.length);
      // TODO(typescript-pending): tagFor's declared ConstantTag union is broader
      // than its implementation, which creates UpdatableTags. Remove when aligned.
      updateTag(propertyTag as UpdatableTag, collectionTag);
    }

    return value;
  }

  // When using EmberObject.create(...), Ember accesses the tracked properties directly
  // through internal references, bypassing the getter/setter defined in this decorator.
  // To work around this, we are using Ember lower level APIs to override the stored references.
  // https://github.com/emberjs/ember.js/blob/d4f7c5c4075bc5b04736e0e965468bdbe6da135c/packages/%40ember/-internals/metal/lib/tracked.ts#L185
  metaFor(target).writeDescriptors(
    key,
    new TrackedDescriptor(autoTrackedArrayGetter, autoTrackedArraySetter)
  );

  return {
    get: autoTrackedArrayGetter,
    set: autoTrackedArraySetter,
    enumerable: true,
    configurable: true,
    isTracked: true,
  };
}

/** @deprecated Use `autoTrackedArray` instead. */
export { autoTrackedArray as trackedArray };

/**
 * Enumerates all tracked property keys from an object instance.
 *
 * **Warning:** This function uses Ember internal APIs (`peekMeta`, `TrackedDescriptor`)
 * which are not part of the public API and may change without notice in future Ember versions.
 *
 * @param obj - The object instance to enumerate tracked keys from
 * @returns An array of tracked property keys.
 *                          Returns an empty array if the object has no prototype or no tracked properties.
 *
 * @example
 * ```js
 * class MyClass {
 *   @tracked name = "Alice";
 *   @tracked age = 30;
 *   regularProp = "not tracked";
 * }
 *
 * const instance = new MyClass();
 * const trackedKeys = enumerateTrackedKeys(instance);
 * // Returns: ["name", "age"]
 * ```
 */
export function enumerateTrackedKeys(obj: object | null | undefined): string[] {
  const prototype = obj?.constructor?.prototype;
  if (!prototype) {
    return [];
  }

  const result = new Set<string>();

  // Walk the prototype chain to collect tracked keys from parent classes too
  let meta = peekMeta(prototype);
  while (meta) {
    const descriptors = meta._descriptors;

    if (descriptors) {
      for (const [key, desc] of descriptors) {
        if (desc instanceof TrackedDescriptor) {
          result.add(key);
        }
      }
    }

    meta = meta.parent;
  }

  return [...result];
}

/**
 * Enumerates all tracked property entries from an object instance.
 *
 * **Warning:** This function uses Ember internal APIs (`peekMeta`, `TrackedDescriptor`)
 * which are not part of the public API and may change without notice in future Ember versions.
 *
 * @param obj - The object instance to enumerate tracked entries from
 * @returns An array of [key, value] pairs for all tracked properties.
 *                                  Returns an empty array if the object has no prototype or no tracked properties.
 *
 * @example
 * ```js
 * class MyClass {
 *   @tracked name = "Alice";
 *   @tracked age = 30;
 *   regularProp = "not tracked";
 * }
 *
 * const instance = new MyClass();
 * const trackedEntries = enumerateTrackedEntries(instance);
 * // Returns: [["name", "Alice"], ["age", 30]]
 * ```
 */
export function enumerateTrackedEntries(
  obj: object | null | undefined
): [string, unknown][] {
  const keys = enumerateTrackedKeys(obj);
  // Tracked keys come from Ember's dynamic descriptor registry, not keyof obj.
  // A nullish obj produces no keys, so the callback only indexes an object.
  return keys.map((key) => [key, (obj as Record<string, unknown>)[key]]);
}

/**
 * A no-op function which is used to signal the intent of consuming a getter
 * for autotracking purposes. The actual autotracking happens when you call
 * the getter, but would trip the `no-unused-expressions` line rule without this
 * wrapper.
 *
 * Consuming state you do not use is generally a violation of Ember's declarative
 * patterns, so reach for this only when absolutely necessary.
 */
export function manuallyTrack(value: unknown): void;
export function manuallyTrack() {}
