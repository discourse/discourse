import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { prefersReducedMotion } from "discourse/lib/utilities";

export default class ScrollController {
  @tracked startSpacerHeight = 0;
  @tracked endSpacerHeight = 0;
  @tracked scrollOngoing = false;
  @tracked overflowX = false;
  @tracked overflowY = false;
  @tracked scrollTrapX = false;
  @tracked scrollTrapY = false;
  viewElement = null;
  contentElement = null;

  startSpacerElement = null;
  endSpacerElement = null;
  axis = "y";
  safeArea = "visual-viewport";
  scrollAnimationSettings = { skip: "auto" };
  pageScroll = false;
  onScroll = null;
  onScrollStart = null;
  onScrollEnd = null;
  scrollingActive = false;
  scrollStartTime = null;
  scrollEndTimeout = null;
  resizeObserver = null;

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

  get usesWindowScroll() {
    return this.pageScroll;
  }

  get scrollTarget() {
    return this.usesWindowScroll ? window : this.viewElement;
  }

  @action
  registerView(element) {
    this.#unobserveElement(this.viewElement);
    this.viewElement = element;
    this.#observeElement(element);
    this.updateOverflowState();
  }

  @action
  registerContent(element) {
    this.#unobserveElement(this.contentElement);
    this.contentElement = element;
    this.#observeElement(element);
    this.updateOverflowState();
  }

  @action
  registerStartSpacer(element) {
    this.#unobserveElement(this.startSpacerElement);
    this.startSpacerElement = element;
    this.#observeElement(element);
  }

  @action
  registerEndSpacer(element) {
    this.#unobserveElement(this.endSpacerElement);
    this.endSpacerElement = element;
    this.#observeElement(element);
  }

  @action
  setupOverflowObserver() {
    if (this.resizeObserver || !this.viewElement) {
      return;
    }

    this.resizeObserver = new ResizeObserver(() => {
      this.updateOverflowState();
    });

    this.#observeElement(this.viewElement);
    this.#observeElement(this.contentElement);
    this.#observeElement(this.startSpacerElement);
    this.#observeElement(this.endSpacerElement);

    this.updateOverflowState();
  }

  #observeElement(element) {
    if (element && this.resizeObserver) {
      this.resizeObserver.observe(element, { box: "border-box" });
    }
  }

  #unobserveElement(element) {
    if (element && this.resizeObserver) {
      this.resizeObserver.unobserve(element);
    }
  }

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

  @action
  getProgress() {
    return this.getDistance() / this.getAvailableDistance();
  }

  @action
  getDistance() {
    if (this.axis === "x") {
      return this.usesWindowScroll
        ? window.scrollX
        : this.viewElement?.scrollLeft;
    }
    return this.usesWindowScroll ? window.scrollY : this.viewElement?.scrollTop;
  }

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

  @action
  getScrollState() {
    return {
      progress: this.getProgress(),
      distance: this.getDistance(),
      availableDistance: this.getAvailableDistance(),
    };
  }

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
