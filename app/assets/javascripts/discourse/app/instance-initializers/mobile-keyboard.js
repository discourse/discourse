import { bind } from "discourse-common/utils/decorators";

export default {
  after: "mobile",

  initialize(owner) {
    const site = owner.lookup("service:site");
    this.capabilities = owner.lookup("service:capabilities");
    this.appEvents = owner.lookup("service:app-events");

    if (!this.capabilities.isIpadOS && site.desktopView) {
      return;
    }

    if (!window.visualViewport) {
      return;
    }

    // TODO: Handle device rotation?
    this.windowInnerHeight = window.innerHeight;

    this.onViewportResize();
    window.visualViewport.addEventListener("resize", this.onViewportResize);
    if ("virtualKeyboard" in navigator) {
      navigator.virtualKeyboard.overlaysContent = true;
      navigator.virtualKeyboard.addEventListener(
        "geometrychange",
        this.onViewportResize
      );
    }
  },

  teardown() {
    window.visualViewport.removeEventListener("resize", this.onViewportResize);
    if ("virtualKeyboard" in navigator) {
      navigator.virtualKeyboard.overlaysContent = false;
      navigator.virtualKeyboard.removeEventListener(
        "geometrychange",
        this.onViewportResize
      );
    }
  },

  @bind
  onViewportResize() {
    const composerVH = window.visualViewport.height * 0.01,
      doc = document.documentElement,
      KEYBOARD_DETECT_THRESHOLD = 150;

    doc.style.setProperty("--composer-vh", `${composerVH}px`);

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
        ) > KEYBOARD_DETECT_THRESHOLD
      ) {
        keyboardVisible = true;
      }
    } else {
      let viewportWindowDiff =
        this.windowInnerHeight - window.visualViewport.height;
      const IPAD_HARDWARE_KEYBOARD_TOOLBAR_HEIGHT = 71.5;
      if (viewportWindowDiff > IPAD_HARDWARE_KEYBOARD_TOOLBAR_HEIGHT) {
        keyboardVisible = true;
      }

      // adds bottom padding when using a hardware keyboard and the accessory bar is visible
      // accessory bar height is 55px, using 75 allows a small buffer
      if (this.capabilities.isIpadOS) {
        doc.style.setProperty(
          "--composer-ipad-padding",
          `${viewportWindowDiff < 75 ? viewportWindowDiff : 0}px`
        );
      }
    }

    this.appEvents.trigger("keyboard-visibility-change", keyboardVisible);

    keyboardVisible
      ? doc.classList.add("keyboard-visible")
      : doc.classList.remove("keyboard-visible");
  },
};
