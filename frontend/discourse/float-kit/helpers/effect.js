import Helper from "@ember/component/helper";
import { registerDestructor } from "@ember/destroyable";

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
