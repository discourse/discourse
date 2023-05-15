import { bind } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { inject as service } from "@ember/service";
import isZoomed from "discourse/plugins/chat/discourse/lib/zoom-check";

const CSS_VAR = "--chat-vh";
let lastVH;

export default class ChatVh extends Component {
  @service capabilities;

  tagName = "";

  didInsertElement() {
    this._super(...arguments);

    if ("virtualKeyboard" in navigator) {
      navigator.virtualKeyboard.overlaysContent = true;
      navigator.virtualKeyboard.addEventListener("geometrychange", this.setVH);
    }

    this.activeWindow = window.visualViewport || window;
    this.activeWindow.addEventListener("resize", this.setVH);
    this.setVH();
  }

  willDestroyElement() {
    this._super(...arguments);

    this.activeWindow?.removeEventListener("resize", this.setVH);
    lastVH = null;

    if ("virtualKeyboard" in navigator) {
      navigator.virtualKeyboard.removeEventListener(
        "geometrychange",
        this.setVH
      );
    }
  }

  @bind
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
      height = this.activeWindow?.height || window.innerHeight;
    }

    const vh = height * 0.01;

    if (lastVH === vh) {
      return;
    }
    lastVH = vh;

    document.documentElement.style.setProperty(CSS_VAR, `${vh}px`);
  }

  #blurActiveElement() {
    if (document.activeElement?.blur) {
      document.activeElement.blur();
    }
  }
}
