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
      navigator.virtualKeyboard.overlaysContent = false;
    }

    this.activeWindow = window.visualViewport || window;
    this.activeWindow.addEventListener("resize", this.setVH);
    this.setVH();
  }

  willDestroyElement() {
    this._super(...arguments);

    this.activeWindow?.removeEventListener("resize", this.setVH);
    lastVH = null;
  }

  @bind
  setVH() {
    if (isZoomed()) {
      return;
    }

    const vh = (this.activeWindow?.height || window.innerHeight) * 0.01;

    if (lastVH === vh) {
      return;
    } else if (this.capabilities.touch && lastVH < vh && vh - lastVH > 1) {
      this.#blurActiveElement();
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
