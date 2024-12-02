import { tracked } from "@glimmer/tracking";
import { next } from "@ember/runloop";
import { TrackedSet } from "tracked-built-ins";

/**
 * Define a tracked property on an object without needing to use the @tracked decorator.
 * Useful when meta-programming the creation of properties on an object.
 *
 * This must be run before the property is first accessed, so it normally makes sense for
 * this to only be called from a constructor.
 */
export function defineTrackedProperty(target, key, value) {
  Object.defineProperty(
    target,
    key,
    tracked(target, key, { enumerable: true, value })
  );
}

class ResettableTrackedState {
  @tracked currentValue;
  previousUpstreamValue;
}

function getOrCreateState(map, instance) {
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
export function resettableTracked(prototype, key, descriptor) {
  // One WeakMap per-property-per-class. Keys are instances of the class
  const states = new WeakMap();

  return {
    get() {
      const state = getOrCreateState(states, this);

      const upstreamValue = descriptor.initializer?.call(this);

      if (upstreamValue !== state.previousUpstreamValue) {
        state.currentValue = upstreamValue;
        state.previousUpstreamValue = upstreamValue;
      }

      return state.currentValue;
    },

    set(value) {
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
export function dedupeTracked(target, key, desc) {
  let { initializer } = desc;
  let { get, set } = tracked(target, key, desc);

  let values = new WeakMap();

  return {
    get() {
      if (!values.has(this)) {
        let value = initializer?.call(this);
        values.set(this, value);
        set.call(this, value);
      }

      return get.call(this);
    },

    set(value) {
      if (!values.has(this) || values.get(this) !== value) {
        values.set(this, value);
        set.call(this, value);
      }
    },
  };
}

export class DeferredTrackedSet {
  #set;

  constructor(value) {
    this.#set = new TrackedSet(value);
  }

  has(value) {
    return this.#set.has(value);
  }

  entries() {
    return this.#set.entries();
  }

  keys() {
    return this.#set.keys();
  }

  values() {
    return this.#set.values();
  }

  forEach(fn) {
    return this.#set.forEach(fn);
  }

  get size() {
    return this.#set.size;
  }

  [Symbol.iterator]() {
    return this.#set[Symbol.iterator]();
  }

  get [Symbol.toStringTag]() {
    return this.#set[Symbol.toStringTag];
  }

  add(value) {
    next(() => this.#set.add(value));
    return this;
  }

  delete(value) {
    next(() => this.#set.delete(value));
    return this;
  }

  clear() {
    next(() => this.#set.clear());
  }
}
