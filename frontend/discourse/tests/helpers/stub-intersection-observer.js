import { settled } from "@ember/test-helpers";
import sinon from "sinon";

/**
 * Stubs `IntersectionObserver` so tests can simulate intersection events.
 * The real one needs viewport scroll state, which the Ember testing container
 * can't reliably provide.
 *
 * @returns {Array<{element, trigger: (overrides?: object) => Promise<void>}>}
 *   Entries appended on each `observe()`.
 *   `await entry.trigger()` fires an intersection event.
 */
export default function stubIntersectionObserver() {
  const observations = [];

  sinon.stub(window, "IntersectionObserver").value(
    class {
      constructor(callback) {
        this.callback = callback;
      }

      observe(element) {
        observations.push({
          element,
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
