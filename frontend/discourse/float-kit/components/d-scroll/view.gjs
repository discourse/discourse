import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import { processBehavior } from "discourse/float-kit/lib/behavior-handler";
import { isKeyboardVisible } from "discourse/lib/utilities";
import { capabilities } from "discourse/services/capabilities";
import mergeScrollAttributes from "../../modifiers/merge-scroll-attributes";
import GestureTrapHandler from "./gesture-trap-handler";
import isTextInput from "./is-text-input";
import KeyboardFocusHandler from "./keyboard-focus-handler";
import SafeAreaHandler from "./safe-area-handler";
import ensureScrollbarThickness from "./scrollbar-thickness";

function notifyScroll(controller, onScroll, event) {
  onScroll?.({
    ...controller.getScrollState(),
    nativeEvent: event,
  });
}

export default class DScrollView extends Component {
  viewElement = null;

  scrollEndTimeout = null;
  isScrolling = false;
  repaintTimeout = null;
  repaintElement = null;
  originalRepaintOpacity = "";
  originalRepaintOpacityPriority = "";

  keyboardHandler = new KeyboardFocusHandler(this);
  safeAreaHandler = new SafeAreaHandler(this);
  gestureTrapHandler = new GestureTrapHandler(this);

  registerElement = modifier(
    (
      element,
      _,
      {
        onRegister,
        onScroll,
        onScrollEnd,
        onFocusIn,
        onFocusOut,
        controller,
        onUnregister,
      }
    ) => {
      ensureScrollbarThickness(element.ownerDocument);
      onRegister(element, controller);

      element.addEventListener("scroll", onScroll, { passive: true });

      if ("onscrollend" in window) {
        element.addEventListener("scrollend", onScrollEnd);
      }

      element.addEventListener("focusin", onFocusIn, { capture: true });
      element.addEventListener("focusout", onFocusOut, { capture: true });

      return () => {
        element.removeEventListener("scroll", onScroll);
        if ("onscrollend" in window) {
          element.removeEventListener("scrollend", onScrollEnd);
        }
        element.removeEventListener("focusin", onFocusIn, { capture: true });
        element.removeEventListener("focusout", onFocusOut, { capture: true });
        onUnregister(element, controller);
      };
    }
  );

  manageGestureTrap = modifier(() => {
    this.gestureTrapHandler.setup();

    return () => this.gestureTrapHandler.teardown();
  });

  manageSafeArea = modifier(() => {
    this.safeAreaHandler.setup();

    return () => this.safeAreaHandler.cleanup();
  });

  registerStartSpy = modifier((element, _, { register, unregister }) => {
    register(element);
    return () => unregister(element);
  });

  registerEndSpy = modifier((element, _, { register, unregister }) => {
    register(element);
    return () => unregister(element);
  });

  registerStartSpacer = modifier((element, _, { register }) => {
    register(element);
    return () => register(null);
  });

  registerEndSpacer = modifier((element, _, { register }) => {
    register(element);
    return () => register(null);
  });

  syncScrollTrapState = modifier(
    (_element, [controller, scrollTrapX, scrollTrapY]) => {
      if (controller) {
        controller.scrollTrapX = scrollTrapX;
        controller.scrollTrapY = scrollTrapY;
      }
    }
  );

  configureController = modifier(
    (
      _element,
      [controller, axis, pageScroll, safeArea, scrollAnimationSettings]
    ) => {
      controller.configure({
        axis,
        pageScroll,
        safeArea,
        scrollAnimationSettings,
      });
    }
  );

  listenForPageScroll = modifier(
    (_element, [controller, pageScroll, onScroll]) => {
      if (!pageScroll || typeof onScroll !== "function") {
        return;
      }

      const handleScroll = (event) => {
        notifyScroll(controller, onScroll, event);
      };

      document.addEventListener("scroll", handleScroll);

      return () => document.removeEventListener("scroll", handleScroll);
    }
  );

  constructor() {
    super(...arguments);

    const controller = this.controller;
    controller.registerViewOwner(this);

    registerDestructor(this, () => {
      controller.unregisterViewOwner(this);
      this.#resetScrollingState();
      this.#restoreRepaintElement();
      this.keyboardHandler.cleanup();
      this.safeAreaHandler.cleanup();
      this.gestureTrapHandler.cleanup();
    });
  }

  #clearScrollEndTimeout() {
    if (this.scrollEndTimeout !== null) {
      clearTimeout(this.scrollEndTimeout);
      this.scrollEndTimeout = null;
    }
  }

  #resetScrollingState() {
    this.#clearScrollEndTimeout();
    this.isScrolling = false;
  }

  #restoreRepaintElement() {
    if (this.repaintTimeout !== null) {
      clearTimeout(this.repaintTimeout);
      this.repaintTimeout = null;
    }

    if (!this.repaintElement) {
      return;
    }

    const repaintElement = this.repaintElement;
    this.repaintElement = null;

    if (
      repaintElement.style.getPropertyValue("opacity") === "0.9999" &&
      repaintElement.style.getPropertyPriority("opacity") === "important"
    ) {
      if (this.originalRepaintOpacity === "") {
        repaintElement.style.removeProperty("opacity");
      } else {
        repaintElement.style.setProperty(
          "opacity",
          this.originalRepaintOpacity,
          this.originalRepaintOpacityPriority
        );
      }
    }

    this.originalRepaintOpacity = "";
    this.originalRepaintOpacityPriority = "";
  }

  get controller() {
    return this.args.controller;
  }

  @action
  handleElementRegister(element, controller) {
    this.viewElement = element;
    controller.registerView(element);
    controller.setupOverflowObserver();
  }

  @action
  handleElementUnregister(element, controller) {
    if (this.viewElement === element) {
      this.#resetScrollingState();
      this.viewElement = null;
    }

    controller.unregisterView(element);
  }

  @action
  registerStartSpyElement(element) {
    this.gestureTrapHandler.registerStartSpy(element);
  }

  @action
  unregisterStartSpyElement(element) {
    this.gestureTrapHandler.unregisterStartSpy(element);
  }

  @action
  registerEndSpyElement(element) {
    this.gestureTrapHandler.registerEndSpy(element);
  }

  @action
  unregisterEndSpyElement(element) {
    this.gestureTrapHandler.unregisterEndSpy(element);
  }

  @action
  registerStartSpacerElement(element) {
    this.controller.registerStartSpacer(element);
  }

  @action
  registerEndSpacerElement(element) {
    this.controller.registerEndSpacer(element);
  }

  get needsSwipeTrapObserver() {
    return this.gestureTrapHandler.needsObserver;
  }

  @action
  updateSafeArea(options) {
    return this.safeAreaHandler.update(options);
  }

  getViewBoundsWithBorder() {
    return this.safeAreaHandler.getViewBoundsWithBorder();
  }

  getVisualViewportBounds() {
    return this.safeAreaHandler.getVisualViewportBounds();
  }

  @action
  onScrollEvent(event) {
    notifyScroll(this.controller, this.args.onScroll, event);

    if (!this.isScrolling) {
      this.isScrolling = true;
      this.handleScrollStart(event);
      this.controller.setScrollOngoing(true);
    }

    this.#clearScrollEndTimeout();
    this.scrollEndTimeout = setTimeout(() => {
      this.scrollEndTimeout = null;
      this.isScrolling = false;
      this.controller.setScrollOngoing(false);
      if (!("onscrollend" in window)) {
        this.handleScrollEnd(null);
      }
    }, 90);
  }

  @action
  onScrollEndEvent(event) {
    this.handleScrollEnd(event);
  }

  @action
  handleScrollStart(event) {
    const { dismissKeyboard } = processBehavior({
      nativeEvent: event,
      defaultBehavior: { dismissKeyboard: false },
      handler: this.args.onScrollStart,
    });

    if (
      dismissKeyboard &&
      !this.keyboardHandler?.scrollTriggeredByFocus &&
      isKeyboardVisible() &&
      this.viewElement
    ) {
      this.viewElement.focus({ preventScroll: true });
    }
  }

  @action
  handleScrollEnd(event) {
    this.keyboardHandler.scrollTriggeredByFocus = false;

    processBehavior({
      nativeEvent: event,
      defaultBehavior: {},
      handler: this.args.onScrollEnd,
    });

    const activeElement = document.activeElement;
    if (!capabilities.isIOS || !isTextInput(activeElement)) {
      return;
    }

    if (this.repaintTimeout === null) {
      this.repaintElement = activeElement;
      this.originalRepaintOpacity =
        activeElement.style.getPropertyValue("opacity");
      this.originalRepaintOpacityPriority =
        activeElement.style.getPropertyPriority("opacity");
      activeElement.style.setProperty("opacity", "0.9999", "important");
    }

    clearTimeout(this.repaintTimeout);
    this.repaintTimeout = setTimeout(() => {
      this.repaintTimeout = null;
      this.#restoreRepaintElement();
    }, 55);
  }

  @action
  onFocusInsideEvent(event) {
    const target = event.target;

    if (target === this.viewElement) {
      return;
    }

    const { scrollIntoView } = processBehavior({
      nativeEvent: event,
      defaultBehavior: { scrollIntoView: true },
      handler: this.args.onFocusInside,
    });

    if (!isTextInput(target)) {
      return;
    }

    this.keyboardHandler.handleFocus(event, scrollIntoView);
  }

  @action
  onBlurInsideEvent(event) {
    this.keyboardHandler.handleBlur(event);
  }

  get viewDataAttribute() {
    const parts = ["view"];
    const axis = this.args.axis === undefined ? "y" : this.args.axis;

    if (axis !== null) {
      parts.push(`axis-${axis}`);
    }

    if (this.args.pageScroll) {
      parts.push("page-scroll");
    }

    if (this.controller?.scrollOngoing) {
      parts.push("scroll-ongoing");
    }

    const scrollAnimationToken = this.scrollAnimationDataAttribute;
    if (scrollAnimationToken) {
      parts.push(scrollAnimationToken);
    }

    return parts.join(" ");
  }

  get scrollContainerDataAttribute() {
    const parts = ["scroll-container"];
    const axis = this.args.axis === undefined ? "y" : this.args.axis;

    if (axis !== null) {
      parts.push(`axis-${axis}`);
    }

    if (this.args.pageScroll) {
      parts.push("page-scroll");
    }

    const nativeScrollbar =
      this.args.nativeScrollbar === undefined
        ? true
        : this.args.nativeScrollbar;
    if (nativeScrollbar === true) {
      parts.push("native-scrollbar");
    } else if (nativeScrollbar === false) {
      parts.push("no-scrollbar");
    }

    if (this.args.scrollAnchoring === false) {
      parts.push("no-anchoring");
    }

    const snapType =
      this.args.scrollSnapType === undefined
        ? "none"
        : this.args.scrollSnapType;
    if (snapType === "proximity") {
      parts.push("snap-proximity");
    } else if (snapType === "mandatory") {
      parts.push("snap-mandatory");
    }

    if (this.args.scrollGestureOvershoot === false) {
      parts.push("no-overshoot");
    }

    const scrollAnimationToken = this.scrollAnimationDataAttribute;
    if (scrollAnimationToken) {
      parts.push(scrollAnimationToken);
    }

    if (this.scrollTrapX) {
      parts.push("trap-x");
    }
    if (this.scrollTrapY) {
      parts.push("trap-y");
    }

    const scrollGesture =
      this.args.scrollGesture === undefined ? "auto" : this.args.scrollGesture;
    if (scrollGesture !== "auto") {
      parts.push("no-scroll-gesture");
    }

    parts.push(this.controller?.overflowX ? "overflow-x" : "no-overflow-x");
    parts.push(this.controller?.overflowY ? "overflow-y" : "no-overflow-y");

    if (this.gestureTrapHandler.swipeTrapIncapable) {
      parts.push("swipe-trap-incapable");
    }

    return parts.join(" ");
  }

  get scrollAnimationDataAttribute() {
    const skipAnimation =
      this.args.scrollAnimationSettings === undefined
        ? "auto"
        : this.args.scrollAnimationSettings?.skip;

    switch (skipAnimation) {
      case true:
        return "scroll-skip";
      case false:
        return "scroll-smooth";
      case "auto":
        return "scroll-auto";
    }

    return null;
  }

  get scrollPaddingStyle() {
    const padding =
      this.args.scrollPadding === undefined ? "auto" : this.args.scrollPadding;

    if (padding === null) {
      return null;
    }

    return `scroll-padding: ${padding};`;
  }

  get scrollTimelineStyle() {
    const timelineName =
      this.args.scrollTimelineName === undefined
        ? "none"
        : this.args.scrollTimelineName;
    const axis = this.args.axis === undefined ? "y" : this.args.axis;
    return `scroll-timeline: ${timelineName} ${axis};`;
  }

  get combinedStyle() {
    const styles = [this.scrollPaddingStyle, this.scrollTimelineStyle]
      .filter(Boolean)
      .join(" ");

    return trustHTML(styles);
  }

  get shouldPreventNativeFocus() {
    return this.args.nativeFocusScrollPrevention === undefined
      ? true
      : this.args.nativeFocusScrollPrevention;
  }

  get scrollTrapX() {
    return this.gestureTrapHandler.xTrap;
  }

  get scrollTrapY() {
    const handler = this.gestureTrapHandler;
    return (
      (!capabilities.isAndroidChromiumBrowser && handler.yTrap) ||
      (handler.keyboardVisible && !handler.swipeTrapIncapable)
    );
  }

  get computedTabIndex() {
    const hasOverflow =
      this.controller?.overflowX || this.controller?.overflowY;
    if (hasOverflow) {
      return "0";
    }
    if (this.shouldPreventNativeFocus) {
      return "-1";
    }
    return undefined;
  }

  get computedRole() {
    const pageScroll =
      this.args.pageScroll === undefined ? false : this.args.pageScroll;

    if (pageScroll) {
      return undefined;
    }
    return "region";
  }

  get axis() {
    return this.args.axis === undefined ? "y" : this.args.axis;
  }

  get scrollGestureTrap() {
    return this.args.scrollGestureTrap;
  }

  get pageScroll() {
    return this.args.pageScroll;
  }

  get safeArea() {
    return this.args.safeArea;
  }

  get sheet() {
    return this.args.sheet;
  }

  get startSpyDataScroll() {
    return `spy spy-start axis-${this.axis}`;
  }

  get endSpyDataScroll() {
    return `spy spy-end axis-${this.axis}`;
  }

  get shouldRenderSpacers() {
    return this.axis === "y";
  }

  get startSpacerDataScroll() {
    return [
      "start-spacer",
      `axis-${this.axis}`,
      this.args.pageScroll && "page-scroll",
    ]
      .filter(Boolean)
      .join(" ");
  }

  get endSpacerDataScroll() {
    return [
      "end-spacer",
      `axis-${this.axis}`,
      this.args.pageScroll && "page-scroll",
    ]
      .filter(Boolean)
      .join(" ");
  }

  get spacerStyle() {
    return trustHTML("height: 0px;");
  }

  <template>
    <div
      ...attributes
      {{mergeScrollAttributes this.viewDataAttribute}}
      {{this.configureController
        this.controller
        @axis
        @pageScroll
        @safeArea
        @scrollAnimationSettings
      }}
      {{this.listenForPageScroll this.controller @pageScroll @onScroll}}
    >
      {{yield}}
    </div>
  </template>
}
