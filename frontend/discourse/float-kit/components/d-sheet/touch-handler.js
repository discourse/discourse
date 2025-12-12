import { cancel } from "@ember/runloop";
import discourseLater from "discourse/lib/later";

/** @type {number} How close to target position to consider "snapped" */
const SNAP_POSITION_TOLERANCE = 1;

/** @type {number} Timeout fallback when scrollend event is not supported */
const SCROLL_END_FALLBACK_TIMEOUT = 90;

/**
 * Touch/pointer gesture handler for d-sheet.
 * Tracks touch state and monitors scroll-snap completion as a backup
 * mechanism for the IntersectionObserver-based dismiss detection.
 *
 * @class TouchHandler
 */
export class TouchHandler {
  /** @type {Object} */
  sheet = null;

  /** @type {boolean} */
  isTrackingScroll = false;

  /** @type {number|null} */
  snapEndTimeout = null;

  /** @type {Function|null} */
  boundSnapEndHandler = null;

  /**
   * Creates a new TouchHandler instance.
   *
   * @param {Object} sheet - The sheet controller instance that owns this handler
   */
  constructor(sheet) {
    this.sheet = sheet;
  }

  /**
   * Handles the start of a touch/scroll gesture.
   * Notifies the sheet controller and begins tracking the scroll.
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
   * Handles the end of a touch/scroll gesture.
   * Notifies the sheet controller and starts monitoring for scroll-snap completion.
   *
   * @returns {void}
   */
  handleScrollEnd() {
    if (!this.isTrackingScroll) {
      return;
    }
    this.sheet.onTouchGestureEnd?.();
    this.startSnapMonitor();
    this.isTrackingScroll = false;
  }

  /**
   * Starts monitoring for scroll-snap completion.
   * Uses the native scrollend event when available, otherwise falls back
   * to a 90ms timeout.
   *
   * @returns {void}
   */
  startSnapMonitor() {
    this.stopSnapMonitor();

    if (!this.sheet.scrollContainer) {
      return;
    }

    this.boundSnapEndHandler = () => {
      this.handleSnapComplete();
    };

    if ("onscrollend" in window) {
      this.sheet.scrollContainer.addEventListener(
        "scrollend",
        this.boundSnapEndHandler,
        { once: true }
      );
    } else {
      this.snapEndTimeout = discourseLater(
        this.boundSnapEndHandler,
        SCROLL_END_FALLBACK_TIMEOUT
      );
    }
  }

  /**
   * Handles scroll-snap completion.
   * Checks if the sheet has snapped to the closed position and triggers
   * close if swipe-out is enabled. This is a backup mechanism for the
   * IntersectionObserver-based dismiss detection.
   *
   * @returns {void}
   */
  handleSnapComplete() {
    const scrollContainer = this.sheet.scrollContainer;
    if (!scrollContainer) {
      this.stopSnapMonitor();
      return;
    }

    const isHorizontal = this.sheet.isHorizontalTrack;
    const scrollPos = isHorizontal
      ? scrollContainer.scrollLeft
      : scrollContainer.scrollTop;
    const scrollMax = isHorizontal
      ? scrollContainer.scrollWidth - scrollContainer.clientWidth
      : scrollContainer.scrollHeight - scrollContainer.clientHeight;

    const contentPlacement = this.sheet.contentPlacement;
    const dismissAtMax = contentPlacement === "start";
    const swipeOutDisabled = this.sheet.swipeOutDisabled;
    const isAtClosedPosition = dismissAtMax
      ? scrollPos >= scrollMax - SNAP_POSITION_TOLERANCE
      : scrollPos < SNAP_POSITION_TOLERANCE;

    if (
      isAtClosedPosition &&
      !swipeOutDisabled &&
      this.sheet.currentState === "open"
    ) {
      this.sheet.close();
    }

    this.stopSnapMonitor();
  }

  /**
   * Stops monitoring for scroll-snap completion.
   * Removes the scrollend event listener and cancels any pending timeout.
   *
   * @returns {void}
   */
  stopSnapMonitor() {
    if (this.boundSnapEndHandler && this.sheet.scrollContainer) {
      this.sheet.scrollContainer.removeEventListener(
        "scrollend",
        this.boundSnapEndHandler
      );
    }
    this.boundSnapEndHandler = null;

    if (this.snapEndTimeout) {
      cancel(this.snapEndTimeout);
      this.snapEndTimeout = null;
    }
  }

  /**
   * Handles touch end events.
   * Delegates to handleScrollEnd for processing.
   *
   * @returns {void}
   */
  handleTouchEnd() {
    this.handleScrollEnd();
  }

  /**
   * Detaches the handler and cleans up resources.
   * Stops snap monitoring and resets tracking state.
   *
   * @returns {void}
   */
  detach() {
    this.stopSnapMonitor();
    this.isTrackingScroll = false;
  }
}
