import Helper from "@ember/component/helper";
import { registerDestructor } from "@ember/destroyable";

/**
 * Build an Ember helper with cleanup logic. The passed function will be called with the named argument,
 * and an 'on' utility object which allows you to register a cleanup function via `on.cleanup(...)`.
 *
 * Whenever any autotracked state is changed, the cleanup function will be run, and your function
 * will be re-evaluated.
 *
 * @param {(args: object, on: { cleanup: () => void } ) => any} fn - The helper function.
 */
export default function helperFn(callback) {
  return class extends Helper {
    cleanupFn = null;

    constructor() {
      super(...arguments);
      registerDestructor(this, this.cleanup);
    }

    compute(positional, named) {
      if (positional.length) {
        throw new Error(
          "Positional arguments are not permitted for helperFn-defined helpers. Use named arguments instead."
        );
      }

      this.cleanup();

      const on = {
        cleanup: (fn) => {
          if (this.cleanupFn) {
            throw new Error("on.cleanup can only be called once");
          }
          this.cleanupFn = fn;
        },
      };

      return callback(named, on);
    }

    cleanup() {
      this.cleanupFn?.();
      this.cleanupFn = null;
    }
  };
}
