import { tracked } from "@glimmer/tracking";
import { cancel, later } from "@ember/runloop";
import Service from "@ember/service";
import { TrackedMap } from "@ember-compat/tracked-built-ins";

/**
 * @class A11yService
 *
 * Accessibility service that handles screen reader announcements and skip links.
 *
 * Key features:
 * - Makes screen reader announcements using ARIA live regions with polite/assertive modes
 * - Manages skip links for keyboard navigation
 * - Uses tracked state for reactive announcements
 * - Automatically cleans up announcements after configurable delay
 * - Provides both polite and assertive announcement levels
 *
 * @example
 * // Polite announcement that clears after 2 seconds
 * a11y.announce("Page loaded", "polite", 2000);
 *
 * // Assertive immediate announcement
 * a11y.announce("Error occurred", "assertive", 1000);
 */
export default class A11y extends Service {
  /**
   * Flag to control visibility of skip links for keyboard navigation
   * @type {boolean}
   */
  @tracked showSkipLinks = true;

  #state = new (class {
    /**
     * Map of screen reader announcements by type
     * @type {TrackedMap<string, string>}
     */
    #messages = new TrackedMap();

    /**
     * Map of announcement clear timers by type
     * @type {TrackedMap<string, EmberRunTimer>}
     */
    #timers = new TrackedMap();

    /**
     * Sets an announcement message with auto-clearing
     * @param {'polite'|'assertive'} type - Type of announcement
     * @param {string} message - Message to announce
     * @param {number} clearDelay - Delay in ms before clearing
     */
    setMessage(type, message, clearDelay) {
      if (message === "") {
        this.#messages.delete(type);
        this.#scheduleClear(type, 0);
        return;
      }

      this.#messages.set(type, message);
      this.#scheduleClear(type, clearDelay);
    }

    /**
     * Gets the current announcement message of specified type
     * @param {'polite'|'assertive'} type - Type of announcement to get
     * @returns {string|undefined} The announcement message if exists
     */
    getMessage(type) {
      return this.#messages.get(type);
    }

    /**
     * Clears all announcement clear timers
     */
    clearTimers() {
      this.#timers.forEach((timer) => {
        if (timer) {
          cancel(timer);
        }
      });
      this.#timers.clear();
    }

    /**
     * Schedule clearing of an announcement after delay
     * @param {'polite'|'assertive'} type - Type of announcement to clear
     * @param {number} clearDelay - Delay in ms before clearing
     */
    #scheduleClear(type, clearDelay) {
      const pendingTimer = this.#timers.get(type);
      if (pendingTimer) {
        cancel(pendingTimer);
        this.#timers.delete(type);
      }

      if (clearDelay > 0) {
        this.#timers.set(
          type,
          later(() => {
            this.#messages.delete(type);
            this.#timers.delete(type);
          }, clearDelay)
        );
      }
    }
  })();

  /**
   * Cleanup timers when service is destroyed
   */
  willDestroy() {
    super.willDestroy(...arguments);
    this.#state.clearTimers();
  }

  /**
   * Gets the current assertive announcement message
   * @type {string|undefined}
   */
  get assertiveMessage() {
    return this.#state.getMessage("assertive");
  }

  /**
   * Gets the current polite announcement message
   * @type {string|undefined}
   */
  get politeMessage() {
    return this.#state.getMessage("polite");
  }

  /**
   * Announce a message to screen readers
   * @param {string} message - The message to announce
   * @param {'polite'|'assertive'} type - The announcement type
   * @param {number} clearDelay - Delay in ms before clearing the message
   * @throws {TypeError} If message is not a string
   * @throws {Error} If clearDelay is not positive or type is invalid
   */
  announce(message, type = "polite", clearDelay = 2000) {
    if (typeof message !== "string") {
      throw new TypeError("The announced message must be a string");
    }

    clearDelay = Math.max(0, Number(clearDelay) || 0);
    if (clearDelay <= 0) {
      throw new Error("The clearDelay must be a positive number");
    }

    switch (type) {
      case "assertive":
      case "polite":
        this.#state.setMessage(type, message.trim(), clearDelay);
        break;
      default:
        throw new Error(
          `Invalid announcement type: ${type}. Expected 'polite' or 'assertive'.`
        );
    }
  }
}
