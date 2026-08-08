import { action } from "@ember/object";
import { cancel, next, scheduleOnce } from "@ember/runloop";
import { getScrollBehavior } from "discourse/lib/utilities";

export function waitForScrollEnd(element, callback, timeout = 300) {
  let timeoutId;
  let active = true;
  let lastScrollTop = element.scrollTop;

  function cleanup() {
    if (!active) {
      return;
    }

    active = false;
    clearTimeout(timeoutId);
    element.removeEventListener("scroll", onScroll);
  }

  function finish() {
    if (!active) {
      return;
    }

    cleanup();
    callback();
  }

  function onScroll() {
    const currentScrollTop = element.scrollTop;
    if (currentScrollTop > lastScrollTop) {
      finish();
      return;
    }
    lastScrollTop = currentScrollTop;
    clearTimeout(timeoutId);
    timeoutId = setTimeout(finish, timeout);
  }

  timeoutId = setTimeout(finish, timeout);
  element.addEventListener("scroll", onScroll);

  return cleanup;
}

export default class SafeAreaHandler {
  previousStartHeight = 0;
  previousEndHeight = 0;
  updateTimeout = null;
  readdListenerTimeout = null;
  fallbackUpdateTimeout = null;
  scrollEndCleanup = null;
  initialUpdateTask = null;
  viewElement = null;

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
    this.viewElement = viewElement;

    window.visualViewport.addEventListener("resize", this.handleResize);

    if (viewElement) {
      viewElement.addEventListener("scroll", this.handleScroll, {
        once: true,
      });
    }

    if (this.view.args.sheet) {
      this.initialUpdateTask = next(this, this.scheduleInitialUpdate);
    } else {
      this.scheduleInitialUpdate();
    }
  }

  @action
  scheduleInitialUpdate() {
    this.initialUpdateTask = scheduleOnce(
      "afterRender",
      this,
      this.runInitialUpdate
    );
  }

  @action
  runInitialUpdate() {
    this.initialUpdateTask = null;
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
    const viewElement = this.viewElement;

    this.cancelScrollEndWait();

    if (this.initialUpdateTask) {
      cancel(this.initialUpdateTask);
      this.initialUpdateTask = null;
    }

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
    this.viewElement = null;
  }

  cancelScrollEndWait() {
    this.scrollEndCleanup?.();
    this.scrollEndCleanup = null;
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

  getSheetContentRestingBounds() {
    const sheet = this.view.args.sheet;
    const dimensions = sheet?.dimensions;
    const sheetView = sheet?.view;

    if (!sheet || !dimensions || !sheetView) {
      return null;
    }

    const dimensionAxis = sheet.isVerticalTrack ? "travelAxis" : "crossAxis";
    const viewSize = dimensions.view?.[dimensionAxis]?.unitless;
    const contentSize = dimensions.content?.[dimensionAxis]?.unitless;

    if (!Number.isFinite(viewSize) || !Number.isFinite(contentSize)) {
      return null;
    }

    const { top: viewTop, bottom: viewBottom } =
      sheetView.getBoundingClientRect();
    const inset = (viewSize - contentSize) / 2;

    switch (sheet.contentPlacement) {
      case "left":
      case "right":
      case "center":
        return { top: viewTop + inset, bottom: viewBottom - inset };
      case "top":
        return { top: viewTop, bottom: viewBottom - 2 * inset };
      case "bottom":
        return { top: viewTop + 2 * inset, bottom: viewBottom };
      default:
        return null;
    }
  }

  getEffectiveViewBounds() {
    const viewBounds = this.getViewBoundsWithBorder();
    const sheet = this.view.args.sheet;

    if (!sheet) {
      return viewBounds;
    }

    const restingBounds = this.getSheetContentRestingBounds();
    const sheetContent = sheet.content;

    if (!restingBounds || !sheetContent) {
      return null;
    }

    const currentSheetBounds = sheetContent.getBoundingClientRect();

    return {
      top: restingBounds.top + (viewBounds.top - currentSheetBounds.top),
      bottom:
        restingBounds.bottom - (currentSheetBounds.bottom - viewBounds.bottom),
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

    const viewBounds = this.getEffectiveViewBounds();
    if (!viewBounds) {
      return;
    }

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

    this.cancelScrollEndWait();

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

        const scrollEndCleanup = waitForScrollEnd(viewElement, () => {
          if (this.scrollEndCleanup === scrollEndCleanup) {
            this.scrollEndCleanup = null;
          }

          if (viewElement && contentFits) {
            viewElement.scrollTo({
              top: 0,
              behavior: "instant",
            });
          }
          setSpacerHeights();
        });
        this.scrollEndCleanup = scrollEndCleanup;
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
