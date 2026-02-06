/**
 * DOM manipulation utilities for d-sheet component system.
 *
 * Manages view-level DOM attributes, inline styles, and element visibility for sheet animations.
 * Handles swipe-out transitions, scroll snap behavior, overflow control during step navigation,
 * and coordinate view positioning. Centralizes all direct DOM manipulation to maintain consistent
 * state across sheet lifecycle events (open, close, navigate, swipe).
 */

import { cancel } from "@ember/runloop";
import discourseLater from "discourse/lib/later";

/**
 * DOM attribute and style management for d-sheet.
 * Centralizes data-d-sheet attribute manipulation and view style updates.
 */
export default class DOMAttributes {
  /**
   * Timer handle for deferred overflow restoration.
   *
   * @type {import("@ember/runloop").Timer | null}
   */
  overflowTimer = null;

  /**
   * Reference to the parent sheet controller.
   *
   * @type {import("./controller").default}
   */
  controller;

  /**
   * @param {import("./controller").default} controller - The sheet controller instance
   */
  constructor(controller) {
    this.controller = controller;
  }

  /**
   * Get the view element from controller.
   *
   * @returns {HTMLElement|null}
   */
  get view() {
    return this.controller.view;
  }

  /**
   * Get the content element from controller.
   *
   * @returns {HTMLElement|null}
   */
  get content() {
    return this.controller.content;
  }

  /**
   * Get the scroll container element from controller.
   *
   * @returns {HTMLElement|null}
   */
  get scrollContainer() {
    return this.controller.scrollContainer;
  }

  /**
   * Add the hidden attribute to the view for initial animation.
   *
   * @returns {void}
   */
  setHidden() {
    if (this.view) {
      const currentAttr = this.view.dataset.dSheet || "";
      const attributes = new Set(currentAttr.split(" ").filter(Boolean));
      attributes.add("hidden");
      this.view.dataset.dSheet = Array.from(attributes).join(" ");
    }
  }

  /**
   * Reset view styles to default state.
   *
   * @returns {void}
   */
  resetViewStyles() {
    if (!this.view) {
      return;
    }

    this.view.style.removeProperty("pointer-events");
    this.view.style.removeProperty("opacity");
  }

  /**
   * Hide the view for swipe-out transition.
   * Applied when intersection observer detects content is no longer visible.
   *
   * @returns {void}
   */
  hideForSwipeOut() {
    if (this.view) {
      this.view.style.setProperty("pointer-events", "none", "important");
      this.view.style.setProperty("opacity", "0", "important");
      this.view.style.setProperty("position", "fixed", "important");
      this.view.style.setProperty("top", "-100px", "important");
      this.view.style.setProperty("left", "-100px", "important");
    }

    if (this.content) {
      this.content.style.setProperty("pointer-events", "none", "important");
    }

    if (this.scrollContainer) {
      this.scrollContainer.style.setProperty("width", "1px", "important");
      this.scrollContainer.style.setProperty("height", "1px", "important");
      this.scrollContainer.style.setProperty(
        "clip-path",
        "inset(0)",
        "important"
      );
    }
  }

  /**
   * Disable scroll snap on the scroll container.
   *
   * @returns {void}
   */
  disableScrollSnap() {
    if (this.scrollContainer) {
      this.scrollContainer.style.setProperty(
        "scroll-snap-type",
        "none",
        "important"
      );
    }
  }

  /**
   * Enable scroll snap on the scroll container (remove override).
   *
   * @returns {void}
   */
  enableScrollSnap() {
    if (this.scrollContainer) {
      this.scrollContainer.style.removeProperty("scroll-snap-type");
    }
  }

  /**
   * Temporarily hide overflow during step animations.
   *
   * @param {number} duration - Duration in ms to hide overflow
   * @returns {void}
   */
  temporarilyHideOverflow(duration) {
    if (!this.scrollContainer) {
      return;
    }

    cancel(this.overflowTimer);

    this.scrollContainer.style.setProperty("overflow", "hidden");

    this.overflowTimer = discourseLater(() => {
      this.scrollContainer?.style.removeProperty("overflow");
    }, duration);
  }

  /**
   * Cleanup any pending timers.
   *
   * @returns {void}
   */
  cleanup() {
    cancel(this.overflowTimer);
  }
}
