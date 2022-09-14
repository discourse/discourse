import Component from "@ember/component";

const KEYBOARD_DETECT_THRESHOLD = 150;

export default Component.extend({
  _detectKeyboard() {
    const doc = document.documentElement;
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
      if (viewportWindowDiff > 0) {
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

    keyboardVisible
      ? doc.classList.add("keyboard-visible")
      : doc.classList.remove("keyboard-visible");
  },

  didInsertElement() {
    if ("virtualKeyboard" in navigator) {
      navigator.virtualKeyboard.overlaysContent = true;
      navigator.virtualKeyboard.addEventListener(
        "geometrychange",
        this._detectKeyboard
      );
    }
    if (
      (this.capabilities.isIpadOS || this.site.mobileView) &&
      window.visualViewport !== undefined
    ) {
      this._detectKeyboard();
      window.visualViewport.addEventListener("resize", this._detectKeyboard);
    }
  },

  willDestroyElement() {
    this._super(...arguments);

    window.visualViewport.removeEventListener("resize", this._detectKeyboard);
    navigator.virtualKeyboard.removeEventListener(
      "geometrychange",
      this._detectKeyboard
    );

    if ("virtualKeyboard" in navigator) {
      navigator.virtualKeyboard.overlaysContent = false;
    }
  },
});
