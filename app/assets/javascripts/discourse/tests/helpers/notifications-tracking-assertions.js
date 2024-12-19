import QUnit from "qunit";
import { query } from "discourse/tests/helpers/qunit-helpers";

class NotificationsTracking {
  constructor(selector, context) {
    this.context = context;
    if (selector instanceof HTMLElement) {
      this.element = selector;
    } else {
      this.element = query(selector);
    }
  }

  hasSelectedLevelName(name, message) {
    this.context
      .dom(this.element)
      .hasAttribute("data-level-name", name, message);
  }

  hasSelectedLevelId(id, message) {
    this.context.dom(this.element).hasAttribute("data-level-id", id, message);
  }
}

export function setupNotificationsTrackingAssertions() {
  QUnit.assert.notificationsTracking = function (
    selector = ".notifications-tracking-trigger"
  ) {
    return new NotificationsTracking(selector, this);
  };
}
