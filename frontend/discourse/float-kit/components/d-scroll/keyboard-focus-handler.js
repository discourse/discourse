import { isCloneElement } from "discourse/float-kit/lib/utils";
import { getScrollBehavior, isKeyboardVisible } from "discourse/lib/utilities";
import { capabilities } from "discourse/services/capabilities";
import isTextInput from "./is-text-input";

/**
 * KeyboardFocusHandler - Manages keyboard focus scroll behavior for DScroll.View.
 *
 * Tracks keyboard open state, scrolls focused text inputs into view during
 * keyboard animation, and uses visualViewport resize events to continuously
 * adjust during keyboard animation.
 *
 * @class KeyboardFocusHandler
 */
export default class KeyboardFocusHandler {
  /** @type {boolean} */
  keyboardAlreadyOpen = false;

  /** @type {boolean} */
  scrollTriggeredByFocus = false;

  /** @type {HTMLElement|null} */
  focusedElement = null;

  /** @type {number} */
  elementTop = 0;

  /** @type {number} */
  elementBottom = 0;

  /** @type {number} */
  scrollPortTop = 0;

  /** @type {number} */
  scrollPortBottom = 0;

  /** @type {number|null} */
  keyboardOpenCleanupTimeout = null;

  /** @type {number|null} */
  keyboardOpeningFallbackTimeout = null;

  /** @type {Function|null} */
  resizeHandler = null;

  /** @type {number|null} */
  scrollFlagResetTimeout = null;

  /**
   * @param {DScrollView} view - The View component instance
   */
  constructor(view) {
    this.view = view;
  }

  /**
   * Handle focus event on text input.
   *
   * @param {FocusEvent} event
   * @param {boolean} shouldScrollIntoView - Whether to scroll element into view
   */
  handleFocus(event, shouldScrollIntoView) {
    const target = event.target;
    const scrollContainer = this.view.viewElement;

    if (!target || !scrollContainer) {
      return;
    }

    if (isCloneElement(target)) {
      return;
    }

    // Set flag immediately to prevent keyboard dismiss during keyboard opening
    // This must happen before any scroll events can fire from visualViewport resize
    this.scrollTriggeredByFocus = true;

    this.clearTimeouts();

    const elementRect = target.getBoundingClientRect();
    this.focusedElement = target;
    this.elementTop = elementRect.top;
    this.elementBottom = elementRect.bottom;

    const viewBounds = this.view.getViewBoundsWithBorder();
    this.scrollPortTop = viewBounds.top;
    this.scrollPortBottom = viewBounds.bottom;

    this.resizeHandler = () => {
      this.clearTimeouts();

      const keyboardOpen = isKeyboardVisible();
      if (!keyboardOpen) {
        return;
      }

      this.keyboardAlreadyOpen = true;

      const viewport = this.view.getVisualViewportBounds();

      const result = this.view.updateSafeArea({
        scrollIntoPlace: false,
        scrollBehavior: "smooth",
        safeArea: this.view.args.safeArea ?? "visual-viewport",
      });
      if (result?.spacersHeightSetter) {
        result.spacersHeightSetter();
      }

      if (shouldScrollIntoView) {
        this.scrollIntoView(viewport);
      }

      this.removeResizeListener();
    };

    if (this.keyboardAlreadyOpen) {
      this.resizeHandler();
      this.addResizeListener();
      this.keyboardOpenCleanupTimeout = setTimeout(() => {
        this.removeResizeListener();
      }, 900);
    } else {
      this.addResizeListener();
      this.keyboardOpeningFallbackTimeout = setTimeout(() => {
        this.removeResizeListener();
        this.resizeHandler();
      }, 900);
    }
  }

  /**
   * Handle blur event on text input.
   *
   * @param {FocusEvent} event
   */
  handleBlur(event) {
    const target = event.target;
    const relatedTarget = event.relatedTarget;

    if (!isTextInput(target)) {
      return;
    }

    if (isCloneElement(target)) {
      return;
    }

    if (isTextInput(relatedTarget)) {
      return;
    }

    this.keyboardAlreadyOpen = false;

    const currentSafeArea = this.view.args.safeArea ?? "visual-viewport";
    this.view.updateSafeArea({
      scrollBehavior: getScrollBehavior(),
      safeArea: currentSafeArea === "none" ? "none" : "layout-viewport",
    });

    this.clearTimeouts();
    this.removeResizeListener();
    this.focusedElement = null;

    // Reset scrollTriggeredByFocus with delay to ensure scroll events
    // from keyboard closing animation are also ignored
    if (this.scrollFlagResetTimeout) {
      clearTimeout(this.scrollFlagResetTimeout);
    }
    this.scrollFlagResetTimeout = setTimeout(() => {
      this.scrollTriggeredByFocus = false;
      this.scrollFlagResetTimeout = null;
    }, 100);
  }

  /**
   * Scroll focused element into view.
   *
   * @param {Object} [cachedViewport] - Optional cached viewport bounds for consistency
   * @param {number} cachedViewport.top - Top of visual viewport
   * @param {number} cachedViewport.bottom - Bottom of visual viewport
   */
  scrollIntoView(cachedViewport) {
    const scrollContainer = this.view.viewElement;
    if (!scrollContainer || !this.focusedElement) {
      return;
    }

    const viewport = cachedViewport ?? this.view.getVisualViewportBounds();

    const elementTop = this.elementTop;
    const elementBottom = this.elementBottom;
    const scrollPortTop = this.scrollPortTop;
    const scrollPortBottom = this.scrollPortBottom;

    const scrollMarginTop = 64;
    const scrollMarginBottom = capabilities.isAndroid ? 102 : 54;

    const visibleTop = Math.max(scrollPortTop, viewport.top);
    const visibleBottom = Math.min(scrollPortBottom, viewport.bottom);

    const spaceAbove = elementTop - visibleTop;
    const spaceBelow = visibleBottom - elementBottom;

    if (spaceAbove < scrollMarginTop) {
      const scrollDelta = Math.max(
        -scrollContainer.scrollTop,
        spaceAbove - scrollMarginTop
      );
      if (scrollDelta !== 0) {
        this.scrollTriggeredByFocus = true;
        scrollContainer.scrollBy({
          top: scrollDelta,
          behavior: getScrollBehavior(),
        });
      }
    } else if (spaceBelow < scrollMarginBottom) {
      const maxScroll =
        scrollContainer.scrollHeight -
        scrollContainer.clientHeight -
        scrollContainer.scrollTop;
      const scrollDelta = Math.min(maxScroll, scrollMarginBottom - spaceBelow);
      if (scrollDelta !== 0) {
        this.scrollTriggeredByFocus = true;
        scrollContainer.scrollBy({
          top: scrollDelta,
          behavior: getScrollBehavior(),
        });
      }
    }
  }

  /**
   * Add visualViewport resize listener.
   */
  addResizeListener() {
    if (this.resizeHandler && window.visualViewport) {
      window.visualViewport.addEventListener("resize", this.resizeHandler);
    }
  }

  /**
   * Remove visualViewport resize listener.
   */
  removeResizeListener() {
    if (this.resizeHandler && window.visualViewport) {
      window.visualViewport.removeEventListener("resize", this.resizeHandler);
    }
  }

  /**
   * Clear all timeouts.
   */
  clearTimeouts() {
    if (this.keyboardOpenCleanupTimeout) {
      clearTimeout(this.keyboardOpenCleanupTimeout);
      this.keyboardOpenCleanupTimeout = null;
    }
    if (this.keyboardOpeningFallbackTimeout) {
      clearTimeout(this.keyboardOpeningFallbackTimeout);
      this.keyboardOpeningFallbackTimeout = null;
    }
  }

  /**
   * Clean up all state and listeners.
   */
  cleanup() {
    this.clearTimeouts();
    this.removeResizeListener();
    this.focusedElement = null;
    this.keyboardAlreadyOpen = false;
    this.scrollTriggeredByFocus = false;
    if (this.scrollFlagResetTimeout) {
      clearTimeout(this.scrollFlagResetTimeout);
      this.scrollFlagResetTimeout = null;
    }
  }
}
