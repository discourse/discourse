import { bind } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import isZoomed from "discourse/plugins/chat/discourse/lib/zoom-check";

const CSS_VAR = "--chat-vh";

export default class ChatVh extends Component {
  tagName = "";

  didInsertElement() {
    this._super(...arguments);

    this.setVHFromVisualViewPort();

    if ("virtualKeyboard" in navigator) {
      navigator.virtualKeyboard.overlaysContent = true;

      navigator.virtualKeyboard.addEventListener(
        "geometrychange",
        this.setVHFromKeyboard
      );
    } else {
      (window?.visualViewport || window).addEventListener(
        "resize",
        this.setVHFromVisualViewPort
      );
    }
  }

  willDestroyElement() {
    this._super(...arguments);

    if ("virtualKeyboard" in navigator) {
      navigator.virtualKeyboard.removeEventListener(
        "geometrychange",
        this.setVHFromKeyboard
      );
    } else {
      (window?.visualViewport || window).removeEventListener(
        "resize",
        this.setVHFromVisualViewPort
      );
    }
  }

  @bind
  setVHFromKeyboard(event) {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    if (isZoomed()) {
      return;
    }

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        const keyboardHeight = event.target.boundingRect.height;
        const viewportHeight =
          window.visualViewport?.height || window.innerHeight;

        const vhInPixels = (viewportHeight - keyboardHeight) * 0.01;
        document.documentElement.style.setProperty(CSS_VAR, `${vhInPixels}px`);
      });
    });
  }

  @bind
  setVHFromVisualViewPort() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    if (isZoomed()) {
      return;
    }

    requestAnimationFrame(() => {
      const vhInPixels =
        (window.visualViewport?.height || window.innerHeight) * 0.01;
      document.documentElement.style.setProperty(CSS_VAR, `${vhInPixels}px`);
    });
  }
}
