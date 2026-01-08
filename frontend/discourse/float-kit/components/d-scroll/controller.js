import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { prefersReducedMotion } from "discourse/lib/utilities";

/**
 * Scroll Controller - manages scroll state and provides imperative methods for programmatic scrolling.
 *
 * @class ScrollController
 */
export default class ScrollController {
  /** @type {HTMLElement|null} */
  @tracked viewElement = null;

  /** @type {HTMLElement|null} */
  @tracked contentElement = null;

  /** @type {number} */
  @tracked startSpacerHeight = 0;

  /** @type {number} */
  @tracked endSpacerHeight = 0;

  /** @type {boolean} - Hides caret during scroll to avoid visual glitches */
  @tracked scrollOngoing = false;

  /** @type {boolean} - Whether content overflows on x-axis */
  @tracked overflowX = false;

  /** @type {boolean} - Whether content overflows on y-axis */
  @tracked overflowY = false;

  /** @type {boolean} - Whether x-axis scroll trap is active */
  @tracked trapX = false;

  /** @type {boolean} - Whether y-axis scroll trap is active */
  @tracked trapY = false;

  /** @type {HTMLElement|null} */
  startSpacerElement = null;

  /** @type {HTMLElement|null} */
  endSpacerElement = null;

  /** @type {string} */
  axis = "y";

  /** @type {string} */
  safeArea = "visual-viewport";

  /** @type {Object} */
  scrollAnimationSettings = { skip: "auto" };

  /** @type {boolean} */
  pageScroll = false;

  /** @type {Function|null} */
  onScroll = null;

  /** @type {Function|null} */
  onScrollStart = null;

  /** @type {Function|null} */
  onScrollEnd = null;

  /** @type {boolean} */
  scrollingActive = false;

  /** @type {number|null} */
  scrollStartTime = null;

  /** @type {number|null} */
  scrollEndTimeout = null;

  /** @type {ResizeObserver|null} */
  resizeObserver = null;

  /**
   * @param {Object} options - Configuration options
   */
  constructor(options = {}) {
    if (options.axis) {
      this.axis = options.axis;
    }
    if (options.scrollAnimationSettings) {
      this.scrollAnimationSettings = options.scrollAnimationSettings;
    }
    if (options.pageScroll !== undefined) {
      this.pageScroll = options.pageScroll;
    }
  }

  /**
   * Whether to use window for scroll operations.
   *
   * @returns {boolean}
   */
  get usesWindowScroll() {
    return this.pageScroll;
  }

  /**
   * Get the scroll target element (window or viewElement).
   *
   * @returns {Window|HTMLElement|null}
   */
  get scrollTarget() {
    return this.usesWindowScroll ? window : this.viewElement;
  }

  /**
   * Register the view element.
   *
   * @param {HTMLElement} element
   */
  @action
  registerView(element) {
    this.viewElement = element;
  }

  /**
   * Register the content element.
   *
   * @param {HTMLElement} element
   */
  @action
  registerContent(element) {
    this.contentElement = element;
  }

  /**
   * Register the start spacer element.
   *
   * @param {HTMLElement|null} element
   */
  @action
  registerStartSpacer(element) {
    this.startSpacerElement = element;
  }

  /**
   * Register the end spacer element.
   *
   * @param {HTMLElement|null} element
   */
  @action
  registerEndSpacer(element) {
    this.endSpacerElement = element;
  }

  /**
   * Set up ResizeObserver to track overflow state.
   * Per Silk (original-source.js lines 12777-12789).
   */
  @action
  setupOverflowObserver() {
    if (this.resizeObserver || !this.viewElement) {
      return;
    }

    this.resizeObserver = new ResizeObserver(() => {
      this.updateOverflowState();
    });

    this.resizeObserver.observe(this.viewElement);
    if (this.contentElement) {
      this.resizeObserver.observe(this.contentElement);
    }

    this.updateOverflowState();
  }

  /**
   * Update overflow state based on current scroll dimensions.
   */
  @action
  updateOverflowState() {
    const el = this.viewElement;
    if (!el) {
      return;
    }

    if (this.axis === "y") {
      this.overflowY = el.scrollHeight > el.clientHeight;
    } else {
      this.overflowX = el.scrollWidth > el.clientWidth;
    }
  }

  /**
   * Returns the scroll progress from 0 to 1.
   *
   * @returns {number}
   */
  @action
  getProgress() {
    return this.getDistance() / this.getAvailableDistance();
  }

  /**
   * Returns the distance in pixels traveled by Content from its start position.
   *
   * @returns {number|undefined}
   */
  @action
  getDistance() {
    if (this.axis === "x") {
      return this.usesWindowScroll
        ? window.scrollX
        : this.viewElement?.scrollLeft;
    }
    return this.usesWindowScroll ? window.scrollY : this.viewElement?.scrollTop;
  }

  /**
   * Returns the total scrollable distance in pixels.
   *
   * @returns {number|undefined}
   */
  @action
  getAvailableDistance() {
    if (this.axis === "x") {
      return this.usesWindowScroll
        ? document.body.scrollWidth - window.innerWidth
        : this.viewElement?.scrollWidth - this.viewElement?.offsetWidth;
    }
    return this.usesWindowScroll
      ? document.body.scrollHeight - window.innerHeight
      : this.viewElement?.scrollHeight - this.viewElement?.offsetHeight;
  }

  /**
   * Make Content travel to the defined progress or distance.
   *
   * @param {Object} options - Scroll options
   * @param {number} [options.progress] - Target progress (0-1)
   * @param {number} [options.distance] - Target distance in pixels
   * @param {Object} [options.animationSettings] - Animation settings { skip: "default" | "auto" | boolean }
   */
  @action
  scrollTo(options = {}) {
    const target = this.scrollTarget;
    if (!target) {
      return;
    }

    const { progress, distance, animationSettings } = options;

    const targetDistance =
      distance ??
      (progress !== undefined ? progress * this.getAvailableDistance() : NaN);

    if (Number.isNaN(targetDistance)) {
      return;
    }

    const behavior = this.getScrollBehavior(animationSettings);

    target.scrollTo({
      [this.axis === "x" ? "left" : "top"]: targetDistance,
      behavior,
    });
  }

  /**
   * Make Content travel by the defined progress or distance.
   *
   * @param {Object} options - Scroll options
   * @param {number} [options.progress] - Progress delta to scroll by
   * @param {number} [options.distance] - Distance delta in pixels to scroll by
   * @param {Object} [options.animationSettings] - Animation settings { skip: "default" | "auto" | boolean }
   */
  @action
  scrollBy(options = {}) {
    const target = this.scrollTarget;
    if (!target) {
      return;
    }

    const { progress, distance, animationSettings } = options;

    const deltaDistance =
      distance ??
      (progress !== undefined ? progress * this.getAvailableDistance() : NaN);

    if (Number.isNaN(deltaDistance)) {
      return;
    }

    const behavior = this.getScrollBehavior(animationSettings);

    target.scrollBy({
      [this.axis === "x" ? "left" : "top"]: deltaDistance,
      behavior,
    });
  }

  /**
   * Get scroll behavior based on animation settings.
   *
   * @param {Object} animationSettings - { skip: "default" | "auto" | boolean }
   * @returns {string} Scroll behavior: "instant", "smooth", or "auto"
   */
  getScrollBehavior(animationSettings) {
    const skip = animationSettings?.skip ?? "default";

    if (skip === true) {
      return "instant";
    }
    if (skip === false) {
      return "smooth";
    }
    if (skip === "default") {
      return "auto";
    }
    return prefersReducedMotion() ? "instant" : "smooth";
  }

  /**
   * Get current scroll state for event callbacks.
   *
   * @returns {{ progress: number, distance: number|undefined, availableDistance: number|undefined }}
   */
  @action
  getScrollState() {
    return {
      progress: this.getProgress(),
      distance: this.getDistance(),
      availableDistance: this.getAvailableDistance(),
    };
  }

  /**
   * Check if scroll is at top/left boundary.
   *
   * @returns {boolean}
   */
  @action
  isAtStart() {
    return this.getDistance() <= 0;
  }

  /**
   * Check if scroll is at bottom/right boundary.
   *
   * @returns {boolean}
   */
  @action
  isAtEnd() {
    const distance = this.getDistance();
    const available = this.getAvailableDistance();
    return distance >= available - 1;
  }

  /**
   * Clean up all resources.
   */
  @action
  cleanup() {
    if (this.scrollEndTimeout) {
      clearTimeout(this.scrollEndTimeout);
      this.scrollEndTimeout = null;
    }
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
      this.resizeObserver = null;
    }
    this.viewElement = null;
    this.contentElement = null;
    this.startSpacerElement = null;
    this.endSpacerElement = null;
    this.onScroll = null;
    this.onScrollStart = null;
    this.onScrollEnd = null;
  }

  /**
   * Update spacer heights for safeArea feature.
   *
   * @param {number} startHeight - Height for start spacer
   * @param {number} endHeight - Height for end spacer
   */
  @action
  updateSpacerHeights(startHeight, endHeight) {
    this.startSpacerHeight = startHeight;
    this.endSpacerHeight = endHeight;

    if (this.startSpacerElement) {
      this.startSpacerElement.style.setProperty("height", startHeight + "px");
    }
    if (this.endSpacerElement) {
      this.endSpacerElement.style.setProperty("height", endHeight + "px");
    }
  }
}
