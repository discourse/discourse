import tippy from "tippy.js";
import { bind } from "discourse-common/utils/decorators";
import discourseDebounce from "discourse-common/lib/debounce";

export class DTooltip {
  #tippyInstance;

  constructor(target, content) {
    this.#tippyInstance = this.#initTippy(target, content);
    if (this.#hasTouchCapabilities()) {
      window.addEventListener("scroll", this.onScroll);
    }
  }

  destroy() {
    if (this.#hasTouchCapabilities()) {
      window.removeEventListener("scroll", this.onScroll);
    }
    this.#tippyInstance.destroy();
  }

  @bind
  onScroll() {
    discourseDebounce(() => this.#tippyInstance.hide(), 10);
  }

  #initTippy(target, content) {
    return tippy(target, {
      interactive: false,
      content,
      trigger: this.#hasTouchCapabilities() ? "click" : "mouseenter",
      theme: "d-tooltip",
      arrow: false,
      placement: "bottom-start",
      onTrigger: this.#stopPropagation,
      onUntrigger: this.#stopPropagation,
    });
  }

  #hasTouchCapabilities() {
    return navigator.maxTouchPoints > 1 || "ontouchstart" in window;
  }

  #stopPropagation(instance, event) {
    event.preventDefault();
    event.stopPropagation();
  }
}
