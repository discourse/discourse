import { click } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";

class Notificationstracking {
  constructor(selector) {
    if (selector instanceof HTMLElement) {
      this.element = selector;
    } else {
      this.element = query(selector);
    }
  }

  async selectLevelId(levelId) {
    await click(this.element);
    const content = this.content();
    await click(content.querySelector(`[data-level-id="${levelId}"]`));
  }

  content() {
    const identifier = this.element.dataset.identifier;
    return document.querySelector(
      `[data-content][data-identifier="${identifier}"]`
    );
  }
}

export default function notificationsTracking(
  selector = ".notifications-tracking-trigger"
) {
  return new Notificationstracking(selector);
}
