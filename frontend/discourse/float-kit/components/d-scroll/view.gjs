import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import { capabilities } from "discourse/services/capabilities";
import GestureTrapHandler from "./gesture-trap-handler";
import isTextInput from "./is-text-input";
import KeyboardFocusHandler from "./keyboard-focus-handler";
import nativeFocusScrollPrevention from "./native-focus-scroll-prevention";
import SafeAreaHandler from "./safe-area-handler";

/**
 * DScroll.View - The scroll container component.
 *
 * @component
 * @param {Object} controller - The scroll controller instance (provided by Root)
 * @param {string} @axis - Scroll axis: "x" or "y" (default: "y")
 * @param {boolean|Object} @scrollGestureTrap - Trap scroll gestures at boundaries
 * @param {boolean} @scrollGestureOvershoot - Allow visual overscroll (default: true)
 * @param {boolean|string} @scrollGesture - Enable scroll gestures (default: "auto")
 * @param {Function} @onScroll - Callback on scroll
 * @param {Function|Object} @onScrollStart - Callback on scroll start
 * @param {Function} @onScrollEnd - Callback on scroll end
 * @param {boolean} @nativeFocusScrollPrevention - Prevent native focus scroll (default: true)
 * @param {Function|Object} @onFocusInside - Callback when descendant receives focus
 * @param {Object} @scrollAnimationSettings - Animation settings for programmatic scroll
 * @param {boolean} @pageScroll - Whether this is a page scroll container (default: false)
 * @param {string} @safeArea - Safe area: "none", "layout-viewport", "visual-viewport" (default: "visual-viewport")
 * @param {boolean} @scrollAnchoring - Enable scroll anchoring (default: true)
 * @param {string} @scrollSnapType - CSS scroll-snap-type value (default: "none")
 * @param {string} @scrollPadding - CSS scroll-padding value (default: "auto")
 * @param {string} @scrollTimelineName - CSS scroll-timeline-name value (default: "none")
 * @param {boolean} @nativeScrollbar - Show native scrollbar (default: true)
 */
export default class DScrollView extends Component {
  @tracked viewElement = null;

  scrollStartTimeout = null;
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
        setupGestureTrap,
        setupSafeArea,
        cleanupGestureTrap,
        cleanupSafeArea,
      }
    ) => {
      onRegister(element);

      element.addEventListener("scroll", onScroll, { passive: true });

      if ("onscrollend" in window) {
        element.addEventListener("scrollend", onScrollEnd);
      }

      element.addEventListener("focusin", onFocusIn, { capture: true });
      element.addEventListener("focusout", onFocusOut, { capture: true });

      setupGestureTrap();
      setupSafeArea();

      return () => {
        element.removeEventListener("scroll", onScroll);
        if ("onscrollend" in window) {
          element.removeEventListener("scrollend", onScrollEnd);
        }
        element.removeEventListener("focusin", onFocusIn, { capture: true });
        element.removeEventListener("focusout", onFocusOut, { capture: true });
        cleanupGestureTrap();
        cleanupSafeArea();
      };
    }
  );

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

  constructor() {
    super(...arguments);

    registerDestructor(this, () => {
      if (this.scrollStartTimeout) {
        clearTimeout(this.scrollStartTimeout);
      }
      if (this.scrollEndTimeout) {
        clearTimeout(this.scrollEndTimeout);
      }
      this.keyboardHandler.cleanup();
      this.safeAreaHandler.cleanup();
      this.gestureTrapHandler.cleanup();
    });
  }

  get controller() {
    return this.args.controller;
  }

  @action
  handleElementRegister(element) {
    this.viewElement = element;
    this.configureController();
    this.controller.registerView(element);
    this.controller.setupOverflowObserver();
  }

  @action
  setupGestureTrap() {
    this.gestureTrapHandler.setup();
  }

  @action
  cleanupGestureTrap() {
    this.gestureTrapHandler.cleanup();
  }

  @action
  setupSafeArea() {
    this.safeAreaHandler.setup();
  }

  @action
  cleanupSafeArea() {
    this.safeAreaHandler.cleanup();
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

  configureController() {
    this.controller.axis = this.args.axis ?? "y";
    this.controller.safeArea = this.args.safeArea ?? "visual-viewport";
    this.controller.scrollAnimationSettings = this.args
      .scrollAnimationSettings ?? { skip: "auto" };
    this.controller.onScroll = this.handleScroll;
    this.controller.onScrollStart = this.handleScrollStart;
    this.controller.onScrollEnd = this.handleScrollEnd;
  }

  /**
   * Whether we need the IntersectionObserver for dynamic trap state.
   *
   * @returns {boolean}
   */
  get needsSwipeTrapObserver() {
    return this.gestureTrapHandler.needsObserver;
  }

  /**
   * Update safeArea spacer heights.
   *
   * @param {Object} options - Options to pass to SafeAreaHandler.update()
   * @returns {Object|undefined}
   */
  @action
  updateSafeArea(options) {
    return this.safeAreaHandler.update(options);
  }

  /**
   * Get view bounds with border adjustment.
   *
   * @returns {{ top: number, bottom: number }}
   */
  getViewBoundsWithBorder() {
    return this.safeAreaHandler.getViewBoundsWithBorder();
  }

  /**
   * Get visual viewport bounds.
   *
   * @returns {{ top: number, bottom: number }}
   */
  getVisualViewportBounds() {
    return this.safeAreaHandler.getVisualViewportBounds();
  }

  @action
  onScrollEvent(event) {
    if (this.args.onScroll) {
      const state = this.controller.getScrollState();
      this.args.onScroll({
        ...state,
        nativeEvent: event,
      });
    }

    if (!this.isScrolling) {
      this.isScrolling = true;
      this.handleScrollStart();
    }

    this.controller.scrollOngoing = true;

    if (this.scrollEndTimeout) {
      clearTimeout(this.scrollEndTimeout);
    }
    this.scrollEndTimeout = setTimeout(() => {
      this.isScrolling = false;
      this.controller.scrollOngoing = false;
      if (!("onscrollend" in window)) {
        this.handleScrollEnd(event);
      }
    }, 90);
  }

  @action
  onScrollEndEvent(event) {
    this.isScrolling = false;
    this.controller.scrollOngoing = false;
    this.handleScrollEnd(event);
  }

  @action
  handleScroll() {
    // Called from controller if needed
  }

  @action
  handleScrollStart() {
    if (this.args.onScrollStart) {
      const defaultBehavior = { dismissKeyboard: false };

      if (typeof this.args.onScrollStart === "function") {
        const customEvent = {
          changeDefault: (changedBehavior) => {
            Object.assign(defaultBehavior, changedBehavior);
          },
          dismissKeyboard: defaultBehavior.dismissKeyboard,
          nativeEvent: null,
        };
        this.args.onScrollStart(customEvent);
      } else if (typeof this.args.onScrollStart === "object") {
        Object.assign(defaultBehavior, this.args.onScrollStart);
      }

      // Don't dismiss keyboard if scroll was triggered by focus event
      if (
        defaultBehavior.dismissKeyboard &&
        !this.keyboardHandler?.scrollTriggeredByFocus &&
        document.activeElement
      ) {
        document.activeElement.blur();
      }
    }
  }

  @action
  handleScrollEnd(event) {
    if (this.args.onScrollEnd) {
      this.args.onScrollEnd({ nativeEvent: event });
    }
  }

  @action
  onFocusInsideEvent(event) {
    const target = event.target;

    if (!isTextInput(target)) {
      return;
    }

    if (target === this.viewElement) {
      return;
    }

    const defaultBehavior = { scrollIntoView: true };

    if (this.args.onFocusInside) {
      if (typeof this.args.onFocusInside === "function") {
        const customEvent = {
          changeDefault: (changedBehavior) => {
            Object.assign(defaultBehavior, changedBehavior);
          },
          scrollIntoView: defaultBehavior.scrollIntoView,
          nativeEvent: event,
        };
        this.args.onFocusInside(customEvent);
      } else if (typeof this.args.onFocusInside === "object") {
        Object.assign(defaultBehavior, this.args.onFocusInside);
      }
    }

    this.keyboardHandler.handleFocus(event, defaultBehavior.scrollIntoView);
  }

  /**
   * Handle blur event inside scroll view.
   *
   * @param {FocusEvent} event
   */
  @action
  onBlurInsideEvent(event) {
    this.keyboardHandler.handleBlur(event);
  }

  @action
  scrollElementIntoView(element) {
    if (!element || !this.viewElement) {
      return;
    }

    const elementRect = element.getBoundingClientRect();
    const viewRect = this.viewElement.getBoundingClientRect();

    const isFullyVisible =
      elementRect.top >= viewRect.top &&
      elementRect.bottom <= viewRect.bottom &&
      elementRect.left >= viewRect.left &&
      elementRect.right <= viewRect.right;

    if (isFullyVisible) {
      return;
    }

    const axis = this.args.axis ?? "y";
    if (axis === "y") {
      if (elementRect.top < viewRect.top) {
        const scrollTop =
          this.viewElement.scrollTop - (viewRect.top - elementRect.top);
        this.viewElement.scrollTo({ top: scrollTop, behavior: "smooth" });
      } else if (elementRect.bottom > viewRect.bottom) {
        const scrollTop =
          this.viewElement.scrollTop + (elementRect.bottom - viewRect.bottom);
        this.viewElement.scrollTo({ top: scrollTop, behavior: "smooth" });
      }
    } else {
      if (elementRect.left < viewRect.left) {
        const scrollLeft =
          this.viewElement.scrollLeft - (viewRect.left - elementRect.left);
        this.viewElement.scrollTo({ left: scrollLeft, behavior: "smooth" });
      } else if (elementRect.right > viewRect.right) {
        const scrollLeft =
          this.viewElement.scrollLeft + (elementRect.right - viewRect.right);
        this.viewElement.scrollTo({ left: scrollLeft, behavior: "smooth" });
      }
    }
  }

  /**
   * Build data-d-scroll attribute value for outer View wrapper.
   *
   * @returns {string}
   */
  get viewDataAttribute() {
    const parts = ["root", "view"];
    const axis = this.args.axis ?? "y";

    parts.push(`axis-${axis}`);

    if (this.controller?.scrollOngoing) {
      parts.push("scroll-ongoing");
    }

    return parts.join(" ");
  }

  /**
   * Build data-d-scroll attribute value for inner scrollContainer element.
   *
   * @returns {string}
   */
  get scrollContainerDataAttribute() {
    const parts = ["scroll-container"];
    const axis = this.args.axis ?? "y";

    parts.push(`axis-${axis}`);

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

    const trapX = this.gestureTrapHandler.xTrap;
    const handler = this.gestureTrapHandler;
    const trapY =
      (!capabilities.isAndroidChromiumBrowser && handler.yTrap) ||
      (handler.keyboardVisible && !handler.swipeTrapIncapable);

    if (trapX) {
      parts.push("trap-x");
    }
    if (trapY) {
      parts.push("trap-y");
    }

    if (this.controller) {
      this.controller.trapX = trapX;
      this.controller.trapY = trapY;
    }

    const scrollGesture = this.args.scrollGesture ?? "auto";
    if (scrollGesture === false) {
      parts.push("no-scroll-gesture");
    }

    if (this.controller?.overflowX) {
      parts.push("overflow-x");
    }
    if (this.controller?.overflowY) {
      parts.push("overflow-y");
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

    return htmlSafe(styles);
  }

  get shouldPreventNativeFocus() {
    return this.args.nativeFocusScrollPrevention ?? true;
  }

  /**
   * Compute tabIndex per Silk (original-source.js line 13580).
   * tabIndex: f ? 0 : u ? -1 : void 0
   * We use 0 as default since we don't have the focusable context from Sheet.
   *
   * @returns {string|undefined}
   */
  get computedTabIndex() {
    if (this.shouldPreventNativeFocus) {
      return "-1";
    }
    return "0";
  }

  /**
   * Compute role per Silk (original-source.js line 13581).
   * role: m && !h ? void 0 : "region"
   * When pageScroll is true and nativePageScrollReplacement is false, omit role.
   *
   * @returns {string|undefined}
   */
  get computedRole() {
    const pageScroll = this.args.pageScroll ?? false;
    const nativePageScrollReplacement =
      this.args.nativePageScrollReplacement ?? false;

    if (pageScroll && !nativePageScrollReplacement) {
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

  /**
   * Whether spacers should be rendered (only for vertical scrolling).
   *
   * @returns {boolean}
   */
  get shouldRenderSpacers() {
    return this.axis === "y";
  }

  get startSpacerDataScroll() {
    return `start-spacer axis-${this.axis}`;
  }

  get endSpacerDataScroll() {
    return `end-spacer axis-${this.axis}`;
  }

  get spacerStyle() {
    return htmlSafe("height: 0px;");
  }

  <template>
    <div data-d-scroll={{this.viewDataAttribute}} ...attributes>
      <div
        data-d-scroll={{this.scrollContainerDataAttribute}}
        style={{this.combinedStyle}}
        tabindex={{this.computedTabIndex}}
        role={{this.computedRole}}
        {{this.registerElement
          onRegister=this.handleElementRegister
          onScroll=this.onScrollEvent
          onScrollEnd=this.onScrollEndEvent
          onFocusIn=this.onFocusInsideEvent
          onFocusOut=this.onBlurInsideEvent
          setupGestureTrap=this.setupGestureTrap
          setupSafeArea=this.setupSafeArea
          cleanupGestureTrap=this.cleanupGestureTrap
          cleanupSafeArea=this.cleanupSafeArea
        }}
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
