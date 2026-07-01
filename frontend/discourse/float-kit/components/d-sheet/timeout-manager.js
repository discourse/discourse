import { cancel } from "@ember/runloop";
import discourseLater from "discourse/lib/later";

export default class TimeoutManager {
  timeouts = new Map();

  schedule(key, callback, delay) {
    this.clear(key);
    const timer = discourseLater(() => {
      this.timeouts.delete(key);
      callback();
    }, delay);
    this.timeouts.set(key, timer);
  }

  clear(key) {
    cancel(this.timeouts.get(key));
    this.timeouts.delete(key);
  }

  cleanup() {
    for (const timer of this.timeouts.values()) {
      cancel(timer);
    }
    this.timeouts.clear();
  }
}
