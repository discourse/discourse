import Helper from "@ember/component/helper";
import { registerDestructor } from "@ember/destroyable";

/**
 * A helper for reactive side effects. Unlike regular helpers which compute values,
 * this helper is explicitly for side effects that should run when dependencies change.
 *
 * The callback receives all positional arguments after the callback itself.
 * To register a cleanup function, return it from the callback.
 *
 * @example
 * // In component:
 * @action
 * handlePresentedChange(presented, defaultPresented) {
 *   // side effect logic here
 *
 *   return () => { ... }; // optional cleanup
 * }
 *
 * // In template:
 * {{effect this.handlePresentedChange @presented @defaultPresented}}
 */
export default class EffectHelper extends Helper {
  cleanupFn = null;

  constructor() {
    super(...arguments);
    registerDestructor(this, () => this.cleanup());
  }

  compute([callback, ...dependencies]) {
    this.cleanup();

    if (typeof callback !== "function") {
      return;
    }

    const result = callback(...dependencies);

    if (typeof result === "function") {
      this.cleanupFn = result;
    }
  }

  cleanup() {
    this.cleanupFn?.();
    this.cleanupFn = null;
  }
}
