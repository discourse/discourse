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
import nativeFocusScrollPrevention from "./native-focus-scroll-prevention";
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

    registerDestructor(this, () => {
      this.#clearScrollEndTimeout();
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
    const axis = this.args.axis ?? "y";

    parts.push(`axis-${axis}`);

    if (this.args.pageScroll) {
      parts.push("page-scroll");
    }

    if (this.controller?.scrollOngoing) {
      parts.push("scroll-ongoing");
    }

    return parts.join(" ");
  }

  get scrollContainerDataAttribute() {
    const parts = ["scroll-container"];
    const axis = this.args.axis ?? "y";

    parts.push(`axis-${axis}`);

    if (this.args.pageScroll) {
      parts.push("page-scroll");
    }

    const showScrollbar = this.args.nativeScrollbar ?? true;
    if (!showScrollbar) {
      parts.push("no-scrollbar");
    }

    const anchoring = this.args.scrollAnchoring ?? true;
    if (!anchoring) {
      parts.push("no-anchoring");
    }

    const snapType = this.args.scrollSnapType ?? "none";
    if (snapType === "proximity") {
      parts.push("snap-proximity");
    } else if (snapType === "mandatory") {
      parts.push("snap-mandatory");
    }

    const overshoot = this.args.scrollGestureOvershoot ?? true;
    if (!overshoot) {
      parts.push("no-overshoot");
    }

    const skipAnimation = this.args.scrollAnimationSettings?.skip ?? "auto";
    if (skipAnimation === true) {
      parts.push("scroll-skip");
    } else if (skipAnimation === false) {
      parts.push("scroll-smooth");
    } else {
      parts.push("scroll-auto");
    }

    if (this.scrollTrapX) {
      parts.push("trap-x");
    }
    if (this.scrollTrapY) {
      parts.push("trap-y");
    }

    const scrollGesture = this.args.scrollGesture ?? "auto";
    if (scrollGesture !== "auto") {
      parts.push("no-scroll-gesture");
    }

    if (this.controller?.overflowX) {
      parts.push("overflow-x");
    }
    if (this.controller?.overflowY) {
      parts.push("overflow-y");
    }

    if (this.gestureTrapHandler.swipeTrapIncapable) {
      parts.push("swipe-trap-incapable");
    }

    return parts.join(" ");
  }

  get scrollPaddingStyle() {
    const padding = this.args.scrollPadding ?? "auto";
    return `scroll-padding: ${padding};`;
  }

  get scrollTimelineStyle() {
    const timelineName = this.args.scrollTimelineName ?? "none";
    const axis = this.args.axis ?? "y";
    return `scroll-timeline: ${timelineName} ${axis};`;
  }

  get combinedStyle() {
    const styles = [this.scrollPaddingStyle, this.scrollTimelineStyle]
      .filter(Boolean)
      .join(" ");

    return trustHTML(styles);
  }

  get shouldPreventNativeFocus() {
    return this.args.nativeFocusScrollPrevention ?? true;
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
    const pageScroll = this.args.pageScroll ?? false;

    if (pageScroll) {
      return undefined;
    }
    return "region";
  }

  get axis() {
    return this.args.axis ?? "y";
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
    <div ...attributes {{mergeScrollAttributes this.viewDataAttribute}}>
      <div
        data-d-scroll={{this.scrollContainerDataAttribute}}
        style={{this.combinedStyle}}
        tabindex={{this.computedTabIndex}}
        role={{this.computedRole}}
        {{this.configureController
          this.controller
          @axis
          @pageScroll
          @safeArea
          @scrollAnimationSettings
        }}
        {{this.listenForPageScroll this.controller @pageScroll @onScroll}}
        {{this.syncScrollTrapState
          this.controller
          this.scrollTrapX
          this.scrollTrapY
        }}
        {{this.registerElement
          onRegister=this.handleElementRegister
          onScroll=this.onScrollEvent
          onScrollEnd=this.onScrollEndEvent
          onFocusIn=this.onFocusInsideEvent
          onFocusOut=this.onBlurInsideEvent
          controller=this.controller
          onUnregister=this.handleElementUnregister
        }}
        {{this.manageGestureTrap @axis @scrollGestureTrap @pageScroll}}
        {{this.manageSafeArea @axis @safeArea @sheet}}
        {{nativeFocusScrollPrevention this.shouldPreventNativeFocus}}
      >
        {{#if this.needsSwipeTrapObserver}}
          <div
            data-d-scroll={{this.startSpyDataScroll}}
            {{this.registerStartSpy
              register=this.registerStartSpyElement
              unregister=this.unregisterStartSpyElement
            }}
          ></div>
        {{/if}}
        {{#if this.shouldRenderSpacers}}
          <div
            data-d-scroll={{this.startSpacerDataScroll}}
            style={{this.spacerStyle}}
            {{this.registerStartSpacer
              register=this.registerStartSpacerElement
            }}
          ></div>
        {{/if}}
        {{yield}}
        {{#if this.shouldRenderSpacers}}
          <div
            data-d-scroll={{this.endSpacerDataScroll}}
            style={{this.spacerStyle}}
            {{this.registerEndSpacer register=this.registerEndSpacerElement}}
          ></div>
        {{/if}}
        {{#if this.needsSwipeTrapObserver}}
          <div
            data-d-scroll={{this.endSpyDataScroll}}
            {{this.registerEndSpy
              register=this.registerEndSpyElement
              unregister=this.unregisterEndSpyElement
            }}
          ></div>
        {{/if}}
      </div>
    </div>
  </template>
}
