import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

/**
 * @class AccessibilityAnnouncerService
 *
 * Service for making screen reader announcements using global live regions.
 * Provides a centralized way to announce messages to assistive technology users.
 * Uses reactive state with aria-atomic for reliable screen reader detection.
 */
export default class AccessibilityAnnouncerService extends Service {
  @tracked politeMessage = "";
  @tracked assertiveMessage = "";
  #politeTimerId = null;
  #assertiveTimerId = null;

  willDestroy() {
    super.willDestroy(...arguments);

    if (this.#politeTimerId) {
      clearTimeout(this.#politeTimerId);
      this.#politeTimerId = null;
    }
    if (this.#assertiveTimerId) {
      clearTimeout(this.#assertiveTimerId);
      this.#assertiveTimerId = null;
    }
  }

  announce(message, type = "polite", clearDelay = 2000) {
    switch (type) {
      case "assertive":
        this.assertiveMessage = message;
        break;
      case "polite":
        this.politeMessage = message;
        break;
      default:
        throw new Error(
          `Invalid announcement type: ${type}. Expected 'polite' or 'assertive'.`
        );
    }

    this.#scheduleClear(type, clearDelay);
  }

  #scheduleClear(type, clearDelay) {
    if (clearDelay > 0) {
      if (type === "polite" && this.#politeTimerId) {
        clearTimeout(this.#politeTimerId);
      } else if (type === "assertive" && this.#assertiveTimerId) {
        clearTimeout(this.#assertiveTimerId);
      }

      const timerId = setTimeout(() => {
        if (type === "polite") {
          this.politeMessage = "";
          this.#politeTimerId = null;
        } else {
          this.assertiveMessage = "";
          this.#assertiveTimerId = null;
        }
      }, clearDelay);

      if (type === "polite") {
        this.#politeTimerId = timerId;
      } else {
        this.#assertiveTimerId = timerId;
      }
    }
  }
}
