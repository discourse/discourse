import { cancel } from "@ember/runloop";
import discourseLater from "discourse/lib/later";

export default class TimeoutManager {
  tasks = new Map();

  schedule(key, callback, delay) {
    this.#schedule(key, callback, delay, discourseLater, cancel);
  }

  scheduleNative(key, callback, delay) {
    this.#schedule(key, callback, delay, setTimeout, clearTimeout);
  }

  scheduleAnimationFrame(key, callback) {
    this.clear(key);
    const frame = requestAnimationFrame(() => {
      this.tasks.delete(key);
      callback();
    });
    this.tasks.set(key, () => cancelAnimationFrame(frame));
  }

  #schedule(key, callback, delay, scheduleTimeout, cancelTimeout) {
    this.clear(key);
    const timer = scheduleTimeout(() => {
      this.tasks.delete(key);
      callback();
    }, delay);
    this.tasks.set(key, () => cancelTimeout(timer));
  }

  clear(key) {
    this.tasks.get(key)?.();
    this.tasks.delete(key);
  }

  cleanup() {
    for (const cancelTask of this.tasks.values()) {
      cancelTask();
    }
    this.tasks.clear();
  }
}
