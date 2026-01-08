import { cancel } from "@ember/runloop";
import discourseLater from "discourse/lib/later";

/**
 * Centralized timeout management for d-sheet controller.
 * Provides named timeout scheduling with automatic cleanup.
 *
 * @class TimeoutManager
 */
export default class TimeoutManager {
  /**
   * @type {Map<string, Object>}
   */
  timeouts = new Map();

  /**
   * Schedule a timeout with a given key.
   * Clears any existing timeout with the same key before scheduling.
   *
   * @param {string} key - Unique identifier for the timeout
   * @param {Function} callback - Function to execute after delay
   * @param {number} delay - Delay in milliseconds
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
   * Clear a specific timeout by key.
   *
   * @param {string} key - Unique identifier for the timeout
   */
  clear(key) {
    cancel(this.timeouts.get(key));
    this.timeouts.delete(key);
  }

  /**
   * Check if a timeout with the given key is currently scheduled.
   *
   * @param {string} key - Unique identifier for the timeout
   * @returns {boolean}
   */
  has(key) {
    return this.timeouts.has(key);
  }

  /**
   * Clear all scheduled timeouts.
   */
  cleanup() {
    for (const timer of this.timeouts.values()) {
      cancel(timer);
    }
    this.timeouts.clear();
  }
}
