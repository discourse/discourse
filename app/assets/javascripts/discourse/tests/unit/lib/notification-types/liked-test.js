import { module, test } from "qunit";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { deepMerge } from "discourse-common/lib/object";
import { createRenderDirector } from "discourse/tests/helpers/notification-types-helper";
import Notification from "discourse/models/notification";
import I18n from "I18n";
import { setupTest } from "ember-qunit";

function getNotification(overrides = {}) {
  return Notification.create(
    deepMerge(
      {
        id: 11,
        user_id: 1,
        notification_type: NOTIFICATION_TYPES.liked,
        read: false,
        high_priority: false,
        created_at: "2022-07-01T06:00:32.173Z",
        post_number: 113,
        topic_id: 449,
        fancy_title: "This is fancy title &lt;a&gt;!",
        slug: "this-is-fancy-title",
        data: {
          topic_title: "this is title before it becomes fancy <a>!",
          username: "osama",
          display_username: "osama",
          username2: "shrek",
          count: 2,
        },
      },
      overrides
    )
  );
}

module("Unit | Notification Types | liked", function (hooks) {
  setupTest(hooks);

  test("label", function (assert) {
    const notification = getNotification();
    const director = createRenderDirector(
      notification,
      "liked",
      this.siteSettings
    );
    notification.data.count = 2;
    assert.strictEqual(
      director.label,
      I18n.t("notifications.liked_by_2_users", {
        username: "osama",
        username2: "shrek",
      }),
      "concatenates both usernames with comma when count is 2"
    );

    notification.data.count = 3;
    assert.strictEqual(
      director.label,
      I18n.t("notifications.liked_by_multiple_users", {
        username: "osama",
        username2: "shrek",
        count: 1,
      }),
      "concatenates 2 usernames with comma and displays the remaining count when count larger than 2"
    );

    notification.data.count = 1;
    delete notification.data.username2;
    assert.strictEqual(
      director.label,
      "osama",
      "displays the liker's username when the count is 1"
    );
  });
});
