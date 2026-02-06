import { cancel } from "@ember/runloop";
import discourseLater from "discourse/lib/later";

/**
 * Centralized timeout management for d-sheet controller.
 * Provides named timeout scheduling with automatic cleanup.
 */
export default class TimeoutManager {
  /** @type {Map<string, EmberRunTimer>} */
  timeouts = new Map();

  /**
   * Schedules a named timeout, replacing any existing one with the same key.
   *
   * @param {string} key - Unique identifier for the timeout
   * @param {Function} callback - Function to execute after delay
   * @param {number} delay - Delay in milliseconds
   * @returns {void}
   */
  schedule(key, callback, delay) {
    this.clear(key);
    const timer = discourseLater(() => {
      this.timeouts.delete(key);
      callback();
    }, delay);
    this.timeouts.set(key, timer);
  }

  /**
   * Cancels and removes a specific timeout by key.
   *
   * @param {string} key - Unique identifier for the timeout
   * @returns {void}
   */
  clear(key) {
    cancel(this.timeouts.get(key));
    this.timeouts.delete(key);
  }

  /**
   * Cancels and removes all scheduled timeouts.
   *
   * @returns {void}
   */
  cleanup() {
    for (const timer of this.timeouts.values()) {
      cancel(timer);
    }
    this.timeouts.clear();
  }
}
