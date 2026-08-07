import { tracked } from "@glimmer/tracking";
import { trackedMap } from "@ember/reactive/collections";
import { cancel, next } from "@ember/runloop";
import Service from "@ember/service";
import { isRailsTesting, isTesting } from "discourse/lib/environment";
import discourseLater from "discourse/lib/later";

let clearAnnouncements = true;

/**
 * Reset announcements auto-clear functionality by enabling it.
 * When enabled, announcements will automatically clear after their configured delay.
 *
 * This function only works in test environments (Qunit and Rails).
 * Used to restore default behavior where announcements auto-clear.
 *
 * USE ONLY FOR TESTING PURPOSES

 * @returns {void}
 */
export function enableClearA11yAnnouncementsInTests() {
  if (isTesting() || isRailsTesting()) {
    clearAnnouncements = true;
  }
}

/**
 * Disable announcements auto-clear functionality.
 * When disabled, announcements will remain visible until manually cleared.
 *
 * This function only works in test environments (Qunit and Rails).
 * Useful for testing that announcements persist for expected duration.
 *
 * USE ONLY FOR TESTING PURPOSES
 *
 * @returns {void}
 */
export function disableClearA11yAnnouncementsInTests() {
  if (isTesting() || isRailsTesting()) {
    clearAnnouncements = false;
  }
}

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

  /**
   * Reference date used to determine if relative dates need to be updated.
   * When this value changes, all relative dates consuming this value will be re-rendered.
   * @type {Date}
   */
  @tracked autoUpdatingRelativeDateRef = new Date();

  #state = new (class {
    /**
     * Map of screen reader announcements by type
     * @type {TrackedMap<string, string>}
     */
    #messages = trackedMap();

    /**
     * Map of announcement clear timers by type
     * @type {TrackedMap<string, EmberRunTimer>}
     */
    #timers = trackedMap();

    /**
     * Map of pending repeat-restore timers by type
     * @type {Map<string, EmberRunTimer>}
     */
    #restores = new Map();

    /**
     * Sets an announcement message with auto-clearing
     * @param {'polite'|'assertive'} type - Type of announcement
     * @param {string} message - Message to announce
     * @param {number} clearDelay - Delay in ms before clearing
     */
    setMessage(type, message, clearDelay) {
      // Two announcements in one tick can queue a restore between this call being scheduled
      // and it running, so the request-time cancel in `announce` cannot be the only one.
      this.cancelRestore(type);

      if (message === "") {
        this.#messages.delete(type);
        this.#scheduleClear(type, 0);
        return;
      }

      // A live region only speaks when its text changes, so writing the same string back is
      // a DOM no-op that no screen reader picks up. Blank the region and restore it a render
      // later to give it a change it can act on.
      if (this.#messages.get(type) === message) {
        this.#messages.delete(type);
        this.#restores.set(
          type,
          next(() => {
            this.#restores.delete(type);
            this.#write(type, message, clearDelay);
          })
        );
        return;
      }

      this.#write(type, message, clearDelay);
    }

    /**
     * Writes the message into the live region and arms its clear timer
     * @param {'polite'|'assertive'} type - Type of announcement
     * @param {string} message - Message to announce
     * @param {number} clearDelay - Delay in ms before clearing
     */
    #write(type, message, clearDelay) {
      this.#messages.set(type, message);

      if (clearAnnouncements) {
        this.#scheduleClear(type, clearDelay);
      }
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
     * Clears all pending announcement timers
     */
    clearTimers() {
      this.#timers.forEach((timer) => {
        if (timer) {
          cancel(timer);
        }
      });
      this.#timers.clear();

      this.#restores.forEach((timer) => cancel(timer));
      this.#restores.clear();
    }

    /**
     * Cancels the pending repeat-restore for a type, if there is one
     * @param {'polite'|'assertive'} type - Type of announcement
     */
    cancelRestore(type) {
      const pendingRestore = this.#restores.get(type);
      if (pendingRestore) {
        cancel(pendingRestore);
        this.#restores.delete(type);
      }
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
          discourseLater(() => {
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

    if (type !== "assertive" && type !== "polite") {
      throw new Error(
        `Invalid announcement type: ${type}. Expected 'polite' or 'assertive'.`
      );
    }

    const trimmed = message.trim();

    // Drop a pending repeat-restore as soon as a newer message is requested rather than a
    // tick later when the write below runs, because the restore is already queued ahead of
    // that write and would otherwise put the older message back first. Restores are held
    // outside tracked state, so cancelling one here is safe during render.
    this.#state.cancelRestore(type);

    // Defer the tracked-state write out of the current render. `announce` is often
    // called from a render-driven data load (e.g. an async content resolution), and
    // writing tracked state synchronously during render trips Ember's
    // backtracking-rerender assertion. `next` runs after the render completes and is
    // awaited by `settled()`; a live region is polled asynchronously, so the one-tick
    // delay is imperceptible.
    next(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.#state.setMessage(type, trimmed, clearDelay);
    });
  }
}
