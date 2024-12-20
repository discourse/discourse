import Component from "@glimmer/component";
import { cancel, scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";
import isZoomed from "discourse/lib/zoom-check";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";

const FF_KEYBOARD_DETECT_THRESHOLD = 150;

export default class DVirtualHeight extends Component {
  @service site;
  @service capabilities;
  @service appEvents;

  constructor() {
    super(...arguments);

    if (!window.visualViewport) {
      return;
    }

    if (!this.capabilities.isIpadOS && this.site.desktopView) {
      return;
    }

    // TODO: Handle device rotation
    this.windowInnerHeight = window.innerHeight;

    scheduleOnce("afterRender", this, this.debouncedOnViewportResize);

    window.visualViewport.addEventListener(
      "resize",
      this.debouncedOnViewportResize
    );
    if ("virtualKeyboard" in navigator) {
      navigator.virtualKeyboard.overlaysContent = true;
      navigator.virtualKeyboard.addEventListener(
        "geometrychange",
        this.debouncedOnViewportResize
      );
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);

    cancel(this.debouncedHandler);

    window.visualViewport.removeEventListener(
      "resize",
      this.debouncedOnViewportResize
    );
    if ("virtualKeyboard" in navigator) {
      navigator.virtualKeyboard.overlaysContent = false;
      navigator.virtualKeyboard.removeEventListener(
        "geometrychange",
        this.debouncedOnViewportResize
      );
    }
  }

  setVH() {
    if (isZoomed()) {
      return;
    }

    let height;
    if ("virtualKeyboard" in navigator) {
      height =
        window.visualViewport.height -
        navigator.virtualKeyboard.boundingRect.height;
    } else {
      const activeWindow = window.visualViewport || window;
      height = activeWindow?.height || window.innerHeight;
    }

    if (this.previousHeight && Math.abs(this.previousHeight - height) <= 1) {
      return false;
    }

    this.previousHeight = height;

    document.documentElement.style.setProperty(
      "--composer-vh",
      `${height / 100}px`
    );

    document.documentElement.style.setProperty("--vvh", `${height}px`);
  }

  @bind
  debouncedOnViewportResize() {
    this.debouncedHandler = discourseDebounce(this, this.onViewportResize, 50);
  }

  @bind
  onViewportResize() {
    const setVHresult = this.setVH();

    if (setVHresult === false) {
      return;
    }

    const docEl = document.documentElement;

    let keyboardVisible = false;
    if ("virtualKeyboard" in navigator) {
      if (navigator.virtualKeyboard.boundingRect.height > 0) {
        keyboardVisible = true;
      }
    } else if (this.capabilities.isFirefox && this.capabilities.isAndroid) {
      if (
        Math.abs(
          this.windowInnerHeight -
            Math.min(window.innerHeight, window.visualViewport.height)
        ) > FF_KEYBOARD_DETECT_THRESHOLD
      ) {
        keyboardVisible = true;
      }
    } else {
      let viewportWindowDiff =
        this.windowInnerHeight - window.visualViewport.height;
      const MIN_THRESHOLD = 20;
      if (viewportWindowDiff > MIN_THRESHOLD) {
        keyboardVisible = true;
      }
    }

    this.appEvents.trigger("keyboard-visibility-change", keyboardVisible);

    keyboardVisible
      ? docEl.classList.add("keyboard-visible")
      : docEl.classList.remove("keyboard-visible");
  }
}
