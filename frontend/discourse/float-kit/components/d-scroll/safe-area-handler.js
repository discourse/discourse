import { action } from "@ember/object";
import { getScrollBehavior } from "discourse/lib/utilities";

export function waitForScrollEnd(element, callback, timeout = 300) {
  let timeoutId;
  let lastScrollTop = element.scrollTop;

  const finish = () => {
    clearTimeout(timeoutId);
    element.removeEventListener("scroll", onScroll);
    callback();
  };

  const onScroll = () => {
    const currentScrollTop = element.scrollTop;
    if (currentScrollTop > lastScrollTop) {
      finish();
      return;
    }
    lastScrollTop = currentScrollTop;
    clearTimeout(timeoutId);
    timeoutId = setTimeout(finish, timeout);
  };

  timeoutId = setTimeout(finish, timeout);
  element.addEventListener("scroll", onScroll);
}

export default class SafeAreaHandler {
  previousStartHeight = 0;
  previousEndHeight = 0;
  updateTimeout = null;
  readdListenerTimeout = null;
  fallbackUpdateTimeout = null;

  constructor(view) {
    this.view = view;
  }

  get isNeeded() {
    const axis = this.view.args.axis ?? "y";
    const safeArea = this.view.args.safeArea ?? "visual-viewport";
    return axis === "y" && safeArea !== "none";
  }

  setup() {
    if (!this.isNeeded || !window.visualViewport) {
      return;
    }

    const viewElement = this.view.viewElement;

    window.visualViewport.addEventListener("resize", this.handleResize);

    if (viewElement) {
      viewElement.addEventListener("scroll", this.handleScroll, {
        once: true,
      });
    }

    this.update();
  }

  @action
  handleScroll() {
    this.update();
  }

  @action
  handleResize() {
    const viewElement = this.view.viewElement;

    if (viewElement) {
      viewElement.removeEventListener("scroll", this.handleScroll);
    }

    if (this.updateTimeout) {
      clearTimeout(this.updateTimeout);
    }
    if (this.readdListenerTimeout) {
      clearTimeout(this.readdListenerTimeout);
    }
    if (this.fallbackUpdateTimeout) {
      clearTimeout(this.fallbackUpdateTimeout);
    }

    this.updateTimeout = setTimeout(() => {
      this.update();

      this.readdListenerTimeout = setTimeout(() => {
        const currentViewElement = this.view.viewElement;
        if (currentViewElement) {
          currentViewElement.addEventListener("scroll", this.handleScroll, {
            once: true,
          });
        }
      }, 200);
    }, 1);

    this.fallbackUpdateTimeout = setTimeout(() => {
      this.update();
    }, 350);
  }

  cleanup() {
    const viewElement = this.view.viewElement;

    if (window.visualViewport) {
      window.visualViewport.removeEventListener("resize", this.handleResize);
    }

    if (viewElement) {
      viewElement.removeEventListener("scroll", this.handleScroll);
    }

    if (this.updateTimeout) {
      clearTimeout(this.updateTimeout);
    }
    if (this.readdListenerTimeout) {
      clearTimeout(this.readdListenerTimeout);
    }
    if (this.fallbackUpdateTimeout) {
      clearTimeout(this.fallbackUpdateTimeout);
    }

    this.updateTimeout = null;
    this.readdListenerTimeout = null;
    this.fallbackUpdateTimeout = null;
  }

  getViewBoundsWithBorder() {
    const viewElement = this.view.viewElement;
    if (!viewElement) {
      return { top: 0, bottom: 0 };
    }

    const rect = viewElement.getBoundingClientRect();
    const style = window.getComputedStyle(viewElement);

    return {
      top: rect.top + parseFloat(style.borderTopWidth),
      bottom: rect.bottom - parseFloat(style.borderBottomWidth),
    };
  }

  getVisualViewportBounds() {
    const visualViewport = window.visualViewport;
    if (!visualViewport) {
      return { top: 0, bottom: window.innerHeight };
    }

    const top = visualViewport.offsetTop;
    return {
      top,
      bottom: top + visualViewport.height,
    };
  }

  update({
    scrollIntoPlace = true,
    scrollBehavior = getScrollBehavior(),
    safeArea,
  } = {}) {
    const viewElement = this.view.viewElement;
    const controller = this.view.controller;
    const contentElement = controller?.contentElement;
    const startSpacerElement = controller?.startSpacerElement;
    const endSpacerElement = controller?.endSpacerElement;

    if (
      !this.isNeeded ||
      !viewElement ||
      !controller ||
      !contentElement ||
      !startSpacerElement ||
      !endSpacerElement
    ) {
      return;
    }

    const effectiveSafeArea =
      safeArea ?? this.view.args.safeArea ?? "visual-viewport";

    const viewBounds = this.getViewBoundsWithBorder();
    const viewTop = viewBounds.top;
    const viewBottom = viewBounds.bottom;

    const viewport = this.getVisualViewportBounds();

    const visibleBottom = Math.min(
      viewBottom,
      effectiveSafeArea === "visual-viewport"
        ? viewport.bottom
        : window.innerHeight
    );

    let startSpacerHeight;
    let endSpacerHeight;

    if (effectiveSafeArea === "visual-viewport") {
      startSpacerHeight = Math.abs(Math.min(viewTop + viewport.top, 0));
      endSpacerHeight = Math.max(viewBottom - viewport.bottom, 0);
    } else {
      startSpacerHeight = Math.abs(Math.min(viewTop, 0));
      endSpacerHeight = Math.max(viewBottom - window.innerHeight, 0);
    }

    if (
      Math.abs(this.previousStartHeight - startSpacerHeight) < 1 &&
      Math.abs(this.previousEndHeight - endSpacerHeight) < 1
    ) {
      return;
    }

    let verticalScrollOffsetRequired = 0;
    if (endSpacerElement) {
      verticalScrollOffsetRequired =
        -1 * (visibleBottom - endSpacerElement.getBoundingClientRect().top);
    }

    const contentFits =
      contentElement &&
      viewElement.offsetHeight - contentElement.offsetHeight >= 0;

    const setSpacerHeights = () => {
      this.previousStartHeight = startSpacerHeight;
      this.previousEndHeight = endSpacerHeight;
      controller.updateSpacerHeights(startSpacerHeight, endSpacerHeight);
    };

    if (
      scrollBehavior === "smooth" &&
      (verticalScrollOffsetRequired < 0 || contentFits)
    ) {
      if (scrollIntoPlace) {
        if (this.view.keyboardHandler) {
          this.view.keyboardHandler.scrollTriggeredByFocus = true;
        }

        if (contentFits) {
          viewElement.scrollTo({
            top: 0,
            behavior: scrollBehavior,
          });
        } else {
          viewElement.scrollBy({
            top: verticalScrollOffsetRequired,
            behavior: scrollBehavior,
          });
        }

        this.previousEndHeight = endSpacerHeight;

        waitForScrollEnd(viewElement, () => {
          if (viewElement && contentFits) {
            viewElement.scrollTo({
              top: 0,
              behavior: "instant",
            });
          }
          setSpacerHeights();
        });
      }
    } else {
      setSpacerHeights();
    }

    if (!scrollIntoPlace) {
      return {
        spacersHeightSetter: setSpacerHeights,
        verticalScrollOffsetRequired,
      };
    }
  }
}
