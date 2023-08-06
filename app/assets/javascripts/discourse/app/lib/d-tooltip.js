import tippy from "tippy.js";

export class DTooltip {
  #tippyInstance;

  constructor(target, content) {
    this.#tippyInstance = this.#initTippy(target, content);
  }

  destroy() {
    this.#tippyInstance.destroy();
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
