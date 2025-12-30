import { cancel } from "@ember/runloop";
import discourseLater from "discourse/lib/later";

/**
 * Tolerance in pixels for determining if scroll has snapped to a position.
 *
 * @type {number}
 */
const SNAP_POSITION_TOLERANCE = 1;

/**
 * Timeout in ms for scrollend fallback when the native scrollend event
 * is not supported.
 *
 * @type {number}
 */
const SCROLL_END_FALLBACK_TIMEOUT = 90;

/**
 * Handles touch/scroll gesture tracking for d-sheet.
 *
 * Primary responsibilities:
 * 1. Track scroll gesture start/end and notify the controller
 * 2. Monitor scroll-snap completion using native scrollend event or timeout fallback
 * 3. Provide backup dismiss detection for center-placed sheets
 *
 * For non-center placements, IntersectionObserver (via ObserverManager) handles
 * dismiss detection. This class provides a backup for center-placed sheets where
 * the IntersectionObserver threshold may not trigger reliably.
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
   * Timeout ID for the scrollend fallback when native event is not supported.
   *
   * @type {number|null}
   */
  scrollendFallbackTimeout = null;

  /**
   * Bound handler function for the scrollend event.
   *
   * @type {Function|null}
   */
  scrollendHandler = null;

  /**
   * @param {Object} sheet - The sheet controller instance
   */
  constructor(sheet) {
    this.sheet = sheet;
  }

  /**
   * Called when a touch/scroll gesture starts.
   * Notifies the controller and begins tracking.
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
   * Uses the native scrollend event when available, falls back to 90ms timeout.
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
        this.scrollendHandler,
        { once: true }
      );
    } else {
      this.scrollendFallbackTimeout = discourseLater(
        this.scrollendHandler,
        SCROLL_END_FALLBACK_TIMEOUT
      );
    }
  }

  /**
   * Called when scroll-snap completes (via scrollend event or timeout).
   * For center-placed sheets, checks if the sheet has snapped to the closed
   * position and triggers dismiss if appropriate.
   */
  handleScrollendComplete() {
    const scrollContainer = this.sheet.scrollContainer;
    if (!scrollContainer) {
      this.stopScrollendMonitor();
      return;
    }

    if (this.sheet.contentPlacement === "center") {
      this.checkClosedPositionForCenterPlacement(scrollContainer);
    }

    this.stopScrollendMonitor();
  }

  /**
   * Checks if a center-placed sheet has snapped to closed position.
   * Triggers close if at closed position and swipe-out is enabled.
   *
   * @param {HTMLElement} scrollContainer - The scroll container element
   */
  checkClosedPositionForCenterPlacement(scrollContainer) {
    const isHorizontal = this.sheet.isHorizontalTrack;
    const scrollPos = isHorizontal
      ? scrollContainer.scrollLeft
      : scrollContainer.scrollTop;
    const scrollMax = isHorizontal
      ? scrollContainer.scrollWidth - scrollContainer.clientWidth
      : scrollContainer.scrollHeight - scrollContainer.clientHeight;

    const tracks = this.sheet.tracks;
    const isTopOrLeftTrack = tracks === "top" || tracks === "left";
    const isAtClosedPosition = isTopOrLeftTrack
      ? scrollPos >= scrollMax - SNAP_POSITION_TOLERANCE
      : scrollPos < SNAP_POSITION_TOLERANCE;

    if (
      isAtClosedPosition &&
      !this.sheet.swipeOutDisabled &&
      this.sheet.currentState === "open"
    ) {
      this.sheet.close();
    }
  }

  /**
   * Stops monitoring for scroll-snap completion.
   * Removes the scrollend event listener and cancels any pending timeout.
   */
  stopScrollendMonitor() {
    if (this.scrollendHandler && this.sheet.scrollContainer) {
      this.sheet.scrollContainer.removeEventListener(
        "scrollend",
        this.scrollendHandler
      );
    }
    this.scrollendHandler = null;

    if (this.scrollendFallbackTimeout) {
      cancel(this.scrollendFallbackTimeout);
      this.scrollendFallbackTimeout = null;
    }
  }

  /**
   * Detaches the handler and cleans up all resources.
   */
  detach() {
    this.stopScrollendMonitor();
    this.isTrackingScroll = false;
  }
}
