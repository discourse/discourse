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

  announce(message, type = "polite", clearDelay) {
    if (clearDelay === undefined) {
      clearDelay = 2000;
    }

    if (type === "assertive") {
      this.assertiveMessage = message;
    } else {
      this.politeMessage = message;
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
