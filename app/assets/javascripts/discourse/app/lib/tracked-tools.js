import { tracked } from "@glimmer/tracking";

/**
 * Define a tracked property on an object without needing to the @tracked decorator.
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

export function resettableTracked(prototype, key, descriptor) {
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
