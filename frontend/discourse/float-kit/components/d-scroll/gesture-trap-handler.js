import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

/**
 * GestureTrapHandler - Manages scroll gesture trap via IntersectionObserver for DScroll.View.
 *
 * Uses IntersectionObserver to detect when at scroll boundaries and controls
 * overscroll-behavior based on position and configuration. Only needed when
 * trap values differ between start and end.
 *
 * @class GestureTrapHandler
 */
export default class GestureTrapHandler {
  /** @type {boolean} */
  @tracked isAtStart = true;

  /** @type {boolean} */
  @tracked isAtEnd = true;

  /** @type {boolean} */
  @tracked xTrap = false;

  /** @type {boolean} */
  @tracked yTrap = false;

  /** @type {boolean} */
  @tracked touchStarted = false;

  /** @type {HTMLElement|null} */
  startSpyElement = null;

  /** @type {HTMLElement|null} */
  endSpyElement = null;

  /** @type {IntersectionObserver|null} */
  observer = null;

  /** @type {Function|null} */
  touchStartHandler = null;

  /**
   * @param {DScrollView} view - The View component instance
   */
  constructor(view) {
    this.view = view;
  }

  /**
   * Get effective trap value (scrollGestureOvershoot false forces trap to true).
   *
   * @returns {boolean|Object}
   */
  get effectiveTrap() {
    if (this.view.args.scrollGestureOvershoot === false) {
      return true;
    }
    return this.view.args.scrollGestureTrap ?? false;
  }

  /**
   * Whether we need the IntersectionObserver for dynamic trap state.
   *
   * @returns {boolean}
   */
  get needsObserver() {
    const values = this.normalizedTrapValues;
    return values.xStart !== values.xEnd || values.yStart !== values.yEnd;
  }

  /**
   * Parse scrollGestureTrap config for specific edge.
   *
   * @param {string} edge - The edge to check (xStart, xEnd, yStart, yEnd)
   * @param {string} axisKey - The axis key (x or y)
   * @returns {boolean}
   */
  getTrapValue(edge, axisKey) {
    const trap = this.effectiveTrap;

    if (typeof trap === "boolean") {
      return trap;
    }

    if (trap && typeof trap === "object") {
      if (typeof trap[edge] === "boolean") {
        return trap[edge];
      }
      if (typeof trap[axisKey] === "boolean") {
        return trap[axisKey];
      }
    }

    return false;
  }

  /**
   * Get normalized trap values with non-scroll axis normalization.
   *
   * @returns {{ xStart: boolean, xEnd: boolean, yStart: boolean, yEnd: boolean }}
   */
  get normalizedTrapValues() {
    const xStart = this.getTrapValue("xStart", "x");
    const xEnd = this.getTrapValue("xEnd", "x");
    const yStart = this.getTrapValue("yStart", "y");
    const yEnd = this.getTrapValue("yEnd", "y");

    const axis = this.view.args.axis ?? "y";

    if (axis === "y") {
      const normalizedX = xStart !== xEnd ? true : xStart;
      return { xStart: normalizedX, xEnd: normalizedX, yStart, yEnd };
    } else {
      const normalizedY = yStart !== yEnd ? true : yStart;
      return { xStart, xEnd, yStart: normalizedY, yEnd: normalizedY };
    }
  }

  /**
   * Whether swipe trap is incapable (pageScroll enabled).
   *
   * @returns {boolean}
   */
  get swipeTrapIncapable() {
    return this.view.args.pageScroll ?? false;
  }

  /**
   * Get the current trap state for the scroll axis.
   *
   * @returns {boolean}
   */
  get currentTrap() {
    const axis = this.view.args.axis ?? "y";
    return axis === "y" ? this.yTrap : this.xTrap;
  }

  /**
   * Get the effective X trap state for CSS tokens.
   *
   * @returns {boolean}
   */
  get effectiveXTrap() {
    return this.xTrap;
  }

  /**
   * Get the effective Y trap state for CSS tokens.
   *
   * @returns {boolean}
   */
  get effectiveYTrap() {
    return (
      (!this.touchStarted && this.yTrap) ||
      (this.isAtEnd && !this.swipeTrapIncapable)
    );
  }

  /**
   * Handle touchstart event to track touch state.
   */
  @action
  handleTouchStart() {
    this.touchStarted = true;
  }

  /**
   * Handle IntersectionObserver entries.
   *
   * @param {string} axis - The scroll axis
   * @param {Object} values - Normalized trap values
   * @param {IntersectionObserverEntry[]} entries - Observer entries
   */
  @action
  handleIntersection(axis, values, entries) {
    for (const entry of entries) {
      if (entry.target === this.startSpyElement) {
        if (entry.isIntersecting) {
          this.isAtStart = true;
          if (axis === "x") {
            this.xTrap = values.xStart;
          } else {
            this.yTrap = values.yStart;
            this.touchStarted = false;
          }
        } else {
          this.isAtStart = false;
        }
      } else if (entry.target === this.endSpyElement) {
        if (entry.isIntersecting) {
          this.isAtEnd = true;
          if (axis === "x") {
            this.xTrap = values.xEnd;
          } else {
            this.yTrap = values.yEnd;
            this.touchStarted = false;
          }
        } else {
          this.isAtEnd = false;
        }
      }
    }

    // Both visible = no trap (no overflow)
    if (this.isAtStart && this.isAtEnd) {
      if (axis === "x") {
        this.xTrap = false;
      } else {
        this.yTrap = false;
        this.touchStarted = false;
      }
    }
  }

  /**
   * Set up IntersectionObserver for scroll gesture trap.
   */
  setup() {
    const viewElement = this.view.viewElement;
    const axis = this.view.args.axis ?? "y";
    const values = this.normalizedTrapValues;

    this.xTrap = values.xStart;
    this.yTrap = values.yStart;

    if (viewElement) {
      viewElement.addEventListener("touchstart", this.handleTouchStart, {
        passive: true,
      });
    }

    if (!viewElement || !this.needsObserver) {
      return;
    }

    this.observer = new IntersectionObserver(
      this.handleIntersection.bind(this, axis, values),
      {
        root: viewElement,
        rootMargin: "0px",
        threshold: [1],
      }
    );

    if (this.startSpyElement) {
      this.observer.observe(this.startSpyElement);
    }
    if (this.endSpyElement) {
      this.observer.observe(this.endSpyElement);
    }
  }

  /**
   * Register start spy element and observe it.
   *
   * @param {HTMLElement} element
   */
  registerStartSpy(element) {
    this.startSpyElement = element;
    if (this.observer && element) {
      this.observer.observe(element);
    }
  }

  /**
   * Unregister start spy element.
   *
   * @param {HTMLElement} element
   */
  unregisterStartSpy(element) {
    if (this.observer && element) {
      this.observer.unobserve(element);
    }
    this.startSpyElement = null;
  }

  /**
   * Register end spy element and observe it.
   *
   * @param {HTMLElement} element
   */
  registerEndSpy(element) {
    this.endSpyElement = element;
    if (this.observer && element) {
      this.observer.observe(element);
    }
  }

  /**
   * Unregister end spy element.
   *
   * @param {HTMLElement} element
   */
  unregisterEndSpy(element) {
    if (this.observer && element) {
      this.observer.unobserve(element);
    }
    this.endSpyElement = null;
  }

  /**
   * Clean up observer and event listeners.
   */
  cleanup() {
    const viewElement = this.view.viewElement;

    if (viewElement) {
      viewElement.removeEventListener("touchstart", this.handleTouchStart);
    }

    if (this.observer) {
      this.observer.disconnect();
      this.observer = null;
    }

    this.startSpyElement = null;
    this.endSpyElement = null;
    this.touchStarted = false;
  }
}
