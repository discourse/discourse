import Component from "@glimmer/component";
import { cancel, scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";
import isZoomed from "discourse/lib/zoom-check";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";

export default class DVirtualHeight extends Component {
  @service site;
  @service capabilities;
  @service appEvents;

  MIN_THRESHOLD = 120;

  constructor() {
    super(...arguments);

    if (!window.visualViewport) {
      return;
    }

    if (!this.capabilities.isIpadOS && this.site.desktopView) {
      return;
    }

    this.windowInnerHeight = window.innerHeight;

    scheduleOnce("afterRender", this, this.debouncedOnViewportResize);

    window.visualViewport.addEventListener(
      "resize",
      this.debouncedOnViewportResize
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);

    cancel(this.debouncedHandler);

    window.visualViewport.removeEventListener(
      "resize",
      this.debouncedOnViewportResize
    );
  }

  setVH() {
    if (isZoomed()) {
      return;
    }

    const height = Math.round(window.visualViewport.height);

    if (this.previousHeight && Math.abs(this.previousHeight - height) <= 1) {
      return false;
    }

    this.previousHeight = height;

    document.documentElement.style.setProperty(
      "--composer-vh",
      `${height / 100}px`
    );
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

    let viewportWindowDiff =
      this.windowInnerHeight - window.visualViewport.height;

    if (viewportWindowDiff > this.MIN_THRESHOLD) {
      keyboardVisible = true;
    }

    this.appEvents.trigger("keyboard-visibility-change", keyboardVisible);

    keyboardVisible
      ? docEl.classList.add("keyboard-visible")
      : docEl.classList.remove("keyboard-visible");
  }
}
