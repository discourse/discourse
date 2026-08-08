import { cancel } from "@ember/runloop";
import discourseLater from "discourse/lib/later";

export default class TimeoutManager {
  timeouts = new Map();

  schedule(key, callback, delay) {
    this.#schedule(key, callback, delay, discourseLater, cancel);
  }

  scheduleNative(key, callback, delay) {
    this.#schedule(key, callback, delay, setTimeout, clearTimeout);
  }

  #schedule(key, callback, delay, scheduleTimeout, cancelTimeout) {
    this.clear(key);
    const timer = scheduleTimeout(() => {
      this.timeouts.delete(key);
      callback();
    }, delay);
    this.timeouts.set(key, () => cancelTimeout(timer));
  }

  clear(key) {
    this.timeouts.get(key)?.();
    this.timeouts.delete(key);
  }

  cleanup() {
    for (const cancelTimeout of this.timeouts.values()) {
      cancelTimeout();
    }
    this.timeouts.clear();
  }
}
