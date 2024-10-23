import Helper from "@ember/component/helper";
import { registerDestructor } from "@ember/destroyable";

export default function helperFn(callback) {
  return class extends Helper {
    compute(positional, named) {
      if (positional.length) {
        throw new Error(
          "Positional arguments are not permitted for helperFn-defined helpers. Use named arguments instead."
        );
      }
      const on = {
        cleanup: (fn) => registerDestructor(this, fn),
      };

      return callback(named, on);
    }
  };
}
