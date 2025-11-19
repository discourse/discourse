import { tracked } from "@glimmer/tracking";
import Helper from "@ember/component/helper";
import { schedule } from "@ember/runloop";

/**
 * Helper which wraps a value. When the input value changes, a new view transition is started,
 * and the returned value is updated during that transition.
 */
export default class extends Helper {
  @tracked deferredValue;

  #computedForFirstTime = false;

  compute([liveValue]) {
    if (!this.#computedForFirstTime) {
      this.#computedForFirstTime = true;
      this.deferredValue = liveValue;
    }

    if (this.deferredValue !== liveValue) {
      if (!document.startViewTransition) {
        // No browser support, but keep async characteristics for consistency
        setTimeout(() => (this.deferredValue = liveValue), 0);
      } else {
        document.startViewTransition(() => {
          this.deferredValue = liveValue;
          return new Promise((resolve) => schedule("afterRender", resolve));
        });
      }
    }

    return this.deferredValue;
  }
}
