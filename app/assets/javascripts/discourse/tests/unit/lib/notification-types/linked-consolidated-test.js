import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Notification from "discourse/models/notification";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { createRenderDirector } from "discourse/tests/helpers/notification-types-helper";
import { deepMerge } from "discourse-common/lib/object";
import { i18n } from "discourse-i18n";

function getNotification(overrides = {}) {
  return Notification.create(
    deepMerge(
      {
        id: 11,
        user_id: 1,
        notification_type: NOTIFICATION_TYPES.linked_consolidated,
        read: false,
        high_priority: false,
        created_at: "2022-07-01T06:00:32.173Z",
        data: {
          topic_title: "this is some topic and it's irrelevant",
          original_post_id: 3294,
          original_post_type: 1,
          original_username: "liker439",
          display_username: "liker439",
          username: "liker439",
          count: 44,
        },
      },
      overrides
    )
  );
}

module("Unit | Notification Types | linked-consolidated", function (hooks) {
  setupTest(hooks);

  test("linkHref", function (assert) {
    const notification = getNotification();
    const director = createRenderDirector(
      notification,
      "linked_consolidated",
      this.siteSettings
    );
    assert.strictEqual(
      director.linkHref,
      "/u/eviltrout/notifications/links?acting_username=liker439",
      "links to the notifications page of the user"
    );
  });

  test("description", function (assert) {
    const notification = getNotification();
    const director = createRenderDirector(
      notification,
      "linked_consolidated",
      this.siteSettings
    );
    assert.strictEqual(
      director.description,
      i18n("notifications.linked_consolidated_description", { count: 44 }),
      "displays the right content"
    );
  });
});
