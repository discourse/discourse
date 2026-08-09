import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel, scheduleOnce } from "@ember/runloop";
import { prefersReducedMotion } from "discourse/lib/utilities";

export default class ScrollController {
  @tracked scrollOngoing = false;
  @tracked overflowX = true;
  @tracked overflowY = true;
  @tracked scrollTrapX = false;
  @tracked scrollTrapY = false;
  viewOwner = null;
  viewElement = null;
  contentElement = null;

  startSpacerElement = null;
  endSpacerElement = null;
  axis = "y";
  safeArea = "visual-viewport";
  scrollAnimationSettings = { skip: "auto" };
  pageScroll = false;
  resizeObserver = null;
  overflowUpdateTask = null;

  constructor(options = {}) {
    this.configure(options);
  }

  configure(options = {}) {
    const previousAxis = this.axis;

    this.axis = options.axis === undefined ? "y" : options.axis;
    this.pageScroll =
      options.pageScroll === undefined ? false : options.pageScroll;
    this.safeArea =
      options.safeArea === undefined ? "visual-viewport" : options.safeArea;
    this.scrollAnimationSettings =
      options.scrollAnimationSettings === undefined
        ? { skip: "auto" }
        : options.scrollAnimationSettings;

    if (this.viewElement && previousAxis !== this.axis) {
      this.scheduleOverflowUpdate();
    }
  }

  get usesWindowScroll() {
    return this.pageScroll;
  }

  get scrollTarget() {
    return this.usesWindowScroll ? window : this.viewElement;
  }

  registerViewOwner(owner) {
    this.viewOwner = owner;
  }

  unregisterViewOwner(owner) {
    if (this.viewOwner === owner) {
      this.viewOwner = null;
    }
  }

  @action
  registerView(element) {
    this.#unobserveElement(this.viewElement);
    this.viewElement = element;
    this.#observeElement(element);
    this.scheduleOverflowUpdate();
  }

  @action
  unregisterView(element) {
    if (this.viewElement !== element) {
      return;
    }

    this.#unobserveElement(element);
    this.viewElement = null;
    this.setScrollOngoing(false);
  }

  @action
  registerContent(element) {
    this.#unobserveElement(this.contentElement);
    this.contentElement = element;
    this.#observeElement(element);
    this.scheduleOverflowUpdate();
  }

  @action
  unregisterContent(element) {
    if (this.contentElement !== element) {
      return;
    }

    this.#unobserveElement(element);
    this.contentElement = null;
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

    this.scheduleOverflowUpdate();
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
  scheduleOverflowUpdate() {
    this.overflowUpdateTask ??= scheduleOnce(
      "afterRender",
      this,
      this.runScheduledOverflowUpdate
    );
  }

  @action
  runScheduledOverflowUpdate() {
    this.overflowUpdateTask = null;
    this.updateOverflowState();
  }

  @action
  updateOverflowState() {
    const el = this.viewElement;
    if (!el) {
      return;
    }

    const nextOverflowX = this.axis === "x" && el.scrollWidth > el.clientWidth;
    const nextOverflowY =
      this.axis === "y" && el.scrollHeight > el.clientHeight;

    if (this.overflowX !== nextOverflowX) {
      this.overflowX = nextOverflowX;
    }
    if (this.overflowY !== nextOverflowY) {
      this.overflowY = nextOverflowY;
    }
  }

  @action
  setScrollOngoing(value) {
    if (this.scrollOngoing !== value) {
      this.scrollOngoing = value;
    }
  }

  @action
  getProgress() {
    return this.getDistance() / this.getAvailableDistance();
  }

  @action
  getDistance() {
    if (this.axis !== "y") {
      return this.usesWindowScroll
        ? window.scrollX
        : this.viewElement?.scrollLeft;
    }
    return this.usesWindowScroll ? window.scrollY : this.viewElement?.scrollTop;
  }

  @action
  getAvailableDistance() {
    if (this.axis !== "y") {
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
      (progress != null ? progress * this.getAvailableDistance() : NaN);

    if (Number.isNaN(Number(targetDistance))) {
      return;
    }

    const behavior = this.getScrollBehavior(animationSettings);

    target.scrollTo({
      [this.axis === "y" ? "top" : "left"]: targetDistance,
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
      (progress != null ? progress * this.getAvailableDistance() : NaN);

    if (Number.isNaN(Number(deltaDistance))) {
      return;
    }

    const behavior = this.getScrollBehavior(animationSettings);

    target.scrollBy({
      [this.axis === "y" ? "top" : "left"]: deltaDistance,
      behavior,
    });
  }

  getScrollBehavior(animationSettings) {
    const settings =
      animationSettings === undefined ? { skip: "default" } : animationSettings;
    const skip = settings?.skip;

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
    if (this.overflowUpdateTask) {
      cancel(this.overflowUpdateTask);
      this.overflowUpdateTask = null;
    }

    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
      this.resizeObserver = null;
    }
    this.viewOwner = null;
    this.viewElement = null;
    this.contentElement = null;
    this.startSpacerElement = null;
    this.endSpacerElement = null;
  }

  @action
  updateSpacerHeights(startHeight, endHeight) {
    if (this.startSpacerElement) {
      this.startSpacerElement.style.setProperty("height", startHeight + "px");
    }
    if (this.endSpacerElement) {
      this.endSpacerElement.style.setProperty("height", endHeight + "px");
    }
  }
}
