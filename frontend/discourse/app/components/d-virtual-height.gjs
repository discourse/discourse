import Component from "@glimmer/component";
import { cancel, scheduleOnce } from "@ember/runloop";
import { service } from "discourse/lib/service";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import isZoomed from "discourse/lib/zoom-check";
import SiteService from "discourse/services/site";
import CapabilitiesService from "discourse/services/capabilities";
import AppEventsService from "discourse/services/app-events";

const KEYBOARD_DETECT_THRESHOLD = 150;

export default class DVirtualHeight extends Component {
  @service(() => SiteService) site;
  @service(() => CapabilitiesService) capabilities;
  @service(() => AppEventsService) appEvents;

  constructor() {
    super(...arguments);

    if (!window.visualViewport) {
      return;
    }

    if (!this.capabilities.isIpadOS && this.site.desktopView) {
      return;
    }

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

    let viewportWindowDiff = window.innerHeight - window.visualViewport.height;

    if (viewportWindowDiff > KEYBOARD_DETECT_THRESHOLD) {
      keyboardVisible = true;
    }

    this.appEvents.trigger("keyboard-visibility-change", keyboardVisible);

    keyboardVisible
      ? docEl.classList.add("keyboard-visible")
      : docEl.classList.remove("keyboard-visible");
  }
}
