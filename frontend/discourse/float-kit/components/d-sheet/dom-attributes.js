import { cancel } from "@ember/runloop";
import discourseLater from "discourse/lib/later";

export default class DOMAttributes {
  controller;
  #overflowState = null;
  #overflowTimer = null;

  constructor(controller) {
    this.controller = controller;
  }

  get view() {
    return this.controller.view;
  }

  get content() {
    return this.controller.content;
  }

  get scrollContainer() {
    return this.controller.scrollContainer;
  }

  setHidden() {
    if (this.view) {
      const currentAttr = this.view.dataset.dSheet || "";
      const attributes = new Set(currentAttr.split(" ").filter(Boolean));
      attributes.add("hidden");
      this.view.dataset.dSheet = Array.from(attributes).join(" ");
    }
  }

  resetViewStyles() {
    if (!this.view) {
      return;
    }

    this.view.style.removeProperty("pointer-events");
    this.view.style.removeProperty("opacity");
  }

  hideForSwipeOut() {
    if (this.view) {
      this.view.style.setProperty("pointer-events", "none", "important");
      this.view.style.setProperty("opacity", "0", "important");
      this.view.style.setProperty("position", "fixed", "important");
      this.view.style.setProperty("top", "-100px", "important");
      this.view.style.setProperty("left", "-100px", "important");
    }

    if (this.content) {
      this.content.style.setProperty("pointer-events", "none", "important");
    }

    if (this.scrollContainer) {
      this.scrollContainer.style.setProperty("width", "1px", "important");
      this.scrollContainer.style.setProperty("height", "1px", "important");
      this.scrollContainer.style.setProperty(
        "clip-path",
        "inset(0)",
        "important"
      );
    }
  }

  disableScrollSnap() {
    if (this.scrollContainer) {
      this.scrollContainer.style.setProperty(
        "scroll-snap-type",
        "none",
        "important"
      );
    }
  }

  enableScrollSnap() {
    if (this.scrollContainer) {
      this.scrollContainer.style.removeProperty("scroll-snap-type");
    }
  }

  temporarilyHideOverflow(duration) {
    const element = this.scrollContainer;

    if (!element) {
      return;
    }

    this.#restoreOverflow();

    this.#overflowState = {
      element,
      priority: element.style.getPropertyPriority("overflow"),
      value: element.style.getPropertyValue("overflow"),
    };
    element.style.setProperty("overflow", "hidden");

    this.#overflowTimer = discourseLater(() => {
      this.#overflowTimer = null;
      this.#restoreOverflow();
    }, duration);
  }

  #restoreOverflow() {
    if (this.#overflowTimer) {
      cancel(this.#overflowTimer);
      this.#overflowTimer = null;
    }

    const state = this.#overflowState;
    this.#overflowState = null;

    if (
      !state ||
      state.element.style.getPropertyValue("overflow") !== "hidden"
    ) {
      return;
    }

    if (state.value) {
      state.element.style.setProperty("overflow", state.value, state.priority);
    } else {
      state.element.style.removeProperty("overflow");
    }
  }

  cleanup() {
    this.#restoreOverflow();
  }
}
