/**
 * Scroll trap modifier for d-sheet overlays that prevents touch scroll gestures
 * from propagating to the underlying page. Works by creating an invisible oversized
 * scrollable area (via CSS ::before) and continuously resetting scroll position to
 * center, effectively "trapping" scroll events. Includes iOS Safari workaround for
 * rubber-band scrolling on devices without overscroll-behavior support.
 */

import { modifier as modifierFn } from "ember-modifier";
import { capabilities } from "discourse/services/capabilities";

/**
 * The scroll trap works by creating an oversized scrollable area (600x600px larger
 * via CSS ::before pseudo-element) and centering the scroll position at (300, 300).
 * When the user attempts to scroll, we immediately reset to center, effectively
 * "trapping" the scroll gesture and preventing it from propagating to the page.
 *
 * @constant {number}
 */
const SCROLL_CENTER_POSITION = 300;

/**
 * Delay in milliseconds before restoring scroll overflow on iOS.
 * This brief hidden/auto cycle prevents iOS Safari's rubber-band effect
 * from triggering unwanted page scrolls.
 *
 * @constant {number}
 */
const IOS_OVERFLOW_RESTORE_DELAY_MS = 10;

/**
 * Determines if the iOS rubber-band scroll workaround is needed.
 * This is required on iOS/iPadOS Safari when `overscroll-behavior: contain`
 * is not supported.
 *
 * @returns {boolean}
 */
function needsIOSRubberBandWorkaround() {
  return (
    capabilities.isAppleMobile && !CSS.supports("overscroll-behavior: contain")
  );
}

/**
 * Scrolls element to center position within the scroll trap area.
 *
 * @param {HTMLElement} element - The element to scroll
 */
function scrollToCenter(element) {
  element.scrollTo(SCROLL_CENTER_POSITION, SCROLL_CENTER_POSITION);
}

/**
 * Temporarily disables then re-enables overflow to prevent iOS Safari's
 * rubber-band scrolling from propagating to the page.
 *
 * @param {HTMLElement} element - The element to apply the workaround to
 */
function applyIOSRubberBandWorkaround(element) {
  element.style.setProperty("overflow", "hidden");
  setTimeout(() => {
    element.style.setProperty("overflow", "auto");
  }, IOS_OVERFLOW_RESTORE_DELAY_MS);
}

/**
 * Scroll trap modifier for d-sheet.
 *
 * Creates a scroll trap by centering at (300, 300) in a 600x600px scrollable area
 * created by CSS ::before pseudo-element. This traps scroll gestures to prevent
 * them from propagating to the page.
 *
 * @param {HTMLElement} element - The element to attach the scroll trap to
 * @param {[boolean]} positional - Whether the scroll trap is active
 * @returns {(() => void) | undefined} Cleanup function or undefined if not active
 */
export const scrollTrapModifier = modifierFn((element, [active]) => {
  if (!active) {
    return;
  }

  const requiresIOSWorkaround = needsIOSRubberBandWorkaround();

  scrollToCenter(element);

  /**
   * Handles scroll events by resetting scroll position to center.
   *
   * @param {Event} e - The scroll event
   */
  const handleScroll = (e) => {
    const target = e.currentTarget;
    scrollToCenter(target);

    if (requiresIOSWorkaround) {
      applyIOSRubberBandWorkaround(target);
    }
  };

  element.addEventListener("scroll", handleScroll);

  /**
   * Observes element size changes and recenters scroll position.
   *
   * @type {ResizeObserver}
   */
  const resizeObserver = new ResizeObserver((entries) => {
    entries.forEach(() => {
      scrollToCenter(element);
    });
  });
  resizeObserver.observe(element, { box: "border-box" });

  return () => {
    element.removeEventListener("scroll", handleScroll);
    resizeObserver.disconnect();
  };
});
