import { isCloneElement } from "discourse/float-kit/lib/utils";
import { getScrollBehavior, isKeyboardVisible } from "discourse/lib/utilities";
import { capabilities } from "discourse/services/capabilities";
import isTextInput from "./is-text-input";

export default class KeyboardFocusHandler {
  keyboardAlreadyOpen = false;
  scrollTriggeredByFocus = false;
  focusedElement = null;
  elementTop = 0;
  elementBottom = 0;
  scrollPortTop = 0;
  scrollPortBottom = 0;
  keyboardOpenCleanupTimeout = null;
  keyboardOpeningFallbackTimeout = null;
  resizeHandler = null;

  constructor(view) {
    this.view = view;
  }

  handleFocus(event, shouldScrollIntoView) {
    const target = event.target;
    const scrollContainer = this.view.viewElement;

    if (!target || !scrollContainer) {
      return;
    }

    if (!isTextInput(target) || isCloneElement(target)) {
      return;
    }

    this.scrollTriggeredByFocus = true;

    this.removeResizeListener();
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

    this.scrollTriggeredByFocus = false;
    this.clearTimeouts();
    this.removeResizeListener();
    this.focusedElement = null;
  }

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

  addResizeListener() {
    if (this.resizeHandler && window.visualViewport) {
      window.visualViewport.addEventListener("resize", this.resizeHandler);
    }
  }

  removeResizeListener() {
    if (this.resizeHandler && window.visualViewport) {
      window.visualViewport.removeEventListener("resize", this.resizeHandler);
    }
  }

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

  cleanup() {
    this.clearTimeouts();
    this.removeResizeListener();
    this.focusedElement = null;
    this.keyboardAlreadyOpen = false;
    this.scrollTriggeredByFocus = false;
  }
}
