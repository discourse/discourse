import { settled } from "@ember/test-helpers";
import sinon from "sinon";

/**
 * Stubs `IntersectionObserver` so tests can simulate intersection events.
 * The real one needs viewport scroll state, which the Ember testing container
 * can't reliably provide.
 *
 * @returns {Array<{element, options, trigger: (overrides?: object) => Promise<void>}>}
 *   Entries appended on each `observe()`. `options` is the bag the observer was constructed
 *   with, so a test can assert how a consumer resolved `root` and `rootMargin`.
 *   `await entry.trigger()` fires an intersection event.
 */
export default function stubIntersectionObserver() {
  const observations = [];

  sinon.stub(window, "IntersectionObserver").value(
    class {
      constructor(callback, options) {
        this.callback = callback;
        this.options = options;
      }

      observe(element) {
        observations.push({
          element,
          options: this.options,
          trigger: async (overrides = {}) => {
            this.callback([
              { target: element, isIntersecting: true, ...overrides },
            ]);
            await settled();
          },
        });
      }

      unobserve() {}
      disconnect() {}
    }
  );

  return observations;
}
