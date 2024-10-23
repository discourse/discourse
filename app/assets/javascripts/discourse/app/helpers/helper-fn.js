import Helper from "@ember/component/helper";
import { registerDestructor } from "@ember/destroyable";

export default function helperFn(callback) {
  return class extends Helper {
    compute(positional, named) {
      const cleanup = (fn) => registerDestructor(this, fn);

      return callback({
        positional,
        named,
        on: {
          cleanup,
        },
      });
    }
  };
}
