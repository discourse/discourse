import { cancel } from "@ember/runloop";
import discourseLater from "discourse/lib/later";

/**
 * DOM attribute and style management for d-sheet.
 * Centralizes data-d-sheet attribute manipulation and view style updates.
 *
 * @class DOMAttributes
 */
export default class DOMAttributes {
  /**
   * Timer for overflow restoration.
   *
   * @type {Object|null}
   */
  overflowTimer = null;

  /**
   * @param {Object} controller - The sheet controller instance
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
   * Get the content wrapper element from controller.
   *
   * @returns {HTMLElement|null}
   */
  get contentWrapper() {
    return this.controller.contentWrapper;
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
   * Update the staging-active attribute on the view element.
   *
   * @param {string} staging - Current staging state
   */
  updateStagingActive(staging) {
    if (!this.view) {
      return;
    }

    const currentAttr = this.view.getAttribute("data-d-sheet") || "";
    const hasAttr = currentAttr.split(" ").includes("staging-active");
    const shouldHaveAttr = staging !== "none";

    if (shouldHaveAttr === hasAttr) {
      return;
    }

    if (shouldHaveAttr) {
      this.view.setAttribute("data-d-sheet", `${currentAttr} staging-active`);
    } else {
      const newAttr = currentAttr
        .split(" ")
        .filter((s) => s !== "staging-active")
        .join(" ");
      this.view.setAttribute("data-d-sheet", newAttr);
    }
  }

  /**
   * Update the animation-active attribute on the view element.
   *
   * @param {boolean} isAnimating - Whether animation is in progress
   */
  updateAnimationActive(isAnimating) {
    if (!this.view) {
      return;
    }

    const currentAttr = this.view.dataset.dSheet || "";
    const hasAttr = currentAttr.includes("animation-active");

    if (isAnimating === hasAttr) {
      return;
    }

    this.view.dataset.dSheet = isAnimating
      ? `${currentAttr} animation-active`.trim()
      : currentAttr.replace(/\s*animation-active\s*/g, " ").trim();
  }

  /**
   * Add the hidden attribute to the view for initial animation.
   */
  setHidden() {
    if (this.view) {
      this.view.dataset.dSheet = this.view.dataset.dSheet + " hidden";
    }
  }

  /**
   * Reset view styles to default state.
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
   */
  hideForSwipeOut() {
    if (this.view) {
      this.view.style.setProperty("pointer-events", "none", "important");
      this.view.style.setProperty("opacity", "0", "important");
      this.view.style.setProperty("position", "fixed", "important");
      this.view.style.setProperty("top", "-100px", "important");
      this.view.style.setProperty("left", "-100px", "important");
    }

    if (this.contentWrapper) {
      this.contentWrapper.style.setProperty(
        "pointer-events",
        "none",
        "important"
      );
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
   */
  cleanup() {
    cancel(this.overflowTimer);
  }
}

