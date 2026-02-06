/**
 * Touch gesture and scroll tracking handler for d-sheet bottom sheet component.
 *
 * Manages touch-based scroll interactions and scroll-snap behavior detection for the d-sheet
 * component. Tracks scroll gesture lifecycle (start/end) and monitors for scroll-snap
 * completion using native scrollend events with fallback timeout. Coordinates with the
 * d-sheet controller to enable gesture-aware animations and state transitions.
 */

import { cancel } from "@ember/runloop";
import discourseLater from "discourse/lib/later";

/**
 * Timeout in ms for detecting scroll end via debounce.
 * Used alongside native scrollend event when supported.
 *
 * @type {number}
 */
const SCROLL_END_TIMEOUT = 90;

/**
 * Handles touch/scroll gesture tracking for d-sheet.
 *
 * Primary responsibilities:
 * 1. Track scroll gesture start/end and notify the controller
 * 2. Monitor scroll-snap completion using native scrollend event with timeout fallback
 *
 * @class TouchHandler
 */
export class TouchHandler {
  /**
   * Reference to the sheet controller that owns this handler.
   *
   * @type {Object}
   */
  sheet = null;

  /**
   * Whether a scroll gesture is currently being tracked.
   *
   * @type {boolean}
   */
  isTrackingScroll = false;

  /**
   * Timeout ID for the scroll end debounce.
   *
   * @type {number|null}
   */
  scrollendTimeout = null;

  /**
   * Bound handler function for the scrollend event.
   *
   * @type {Function|null}
   */
  scrollendHandler = null;

  /**
   * Creates a new TouchHandler instance.
   *
   * @param {Object} sheet - The sheet controller instance
   */
  constructor(sheet) {
    this.sheet = sheet;
  }

  /**
   * Called when a touch/scroll gesture starts.
   * Notifies the controller and begins tracking.
   *
   * @returns {void}
   */
  handleScrollStart() {
    if (!this.sheet.scrollContainer) {
      return;
    }
    this.sheet.onTouchGestureStart?.();
    this.isTrackingScroll = true;
  }

  /**
   * Called when a touch/scroll gesture ends.
   * Notifies the controller and starts monitoring for scroll-snap completion.
   *
   * @returns {void}
   */
  handleScrollEnd() {
    if (!this.isTrackingScroll) {
      return;
    }
    this.sheet.onTouchGestureEnd?.();
    this.startScrollendMonitor();
    this.isTrackingScroll = false;
  }

  /**
   * Starts monitoring for scroll-snap completion.
   * Always uses timeout for debounce; also uses native scrollend when supported.
   *
   * @returns {void}
   */
  startScrollendMonitor() {
    this.stopScrollendMonitor();

    if (!this.sheet.scrollContainer) {
      return;
    }

    this.scrollendHandler = () => {
      this.handleScrollendComplete();
    };

    if ("onscrollend" in window) {
      this.sheet.scrollContainer.addEventListener(
        "scrollend",
        this.scrollendHandler
      );
    }

    this.scrollendTimeout = discourseLater(() => {
      this.isTrackingScroll = false;
      if (!("onscrollend" in window)) {
        this.scrollendHandler?.();
      }
    }, SCROLL_END_TIMEOUT);
  }

  /**
   * Called when scroll-snap completes (via scrollend event or timeout).
   *
   * @returns {void}
   */
  handleScrollendComplete() {
    this.stopScrollendMonitor();
  }

  /**
   * Stops monitoring for scroll-snap completion.
   * Removes the scrollend event listener and cancels any pending timeout.
   *
   * @returns {void}
   */
  stopScrollendMonitor() {
    if (this.scrollendHandler && this.sheet.scrollContainer) {
      this.sheet.scrollContainer.removeEventListener(
        "scrollend",
        this.scrollendHandler
      );
    }
    this.scrollendHandler = null;

    if (this.scrollendTimeout) {
      cancel(this.scrollendTimeout);
      this.scrollendTimeout = null;
    }
  }

  /**
   * Detaches the handler and cleans up all resources.
   *
   * @returns {void}
   */
  detach() {
    this.stopScrollendMonitor();
    this.isTrackingScroll = false;
  }
}
