import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { deepMerge } from "discourse/lib/object";
import Notification from "discourse/models/notification";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { createRenderDirector } from "discourse/tests/helpers/notification-types-helper";

function getNotification(overrides = {}) {
  return Notification.create(
    deepMerge(
      {
        id: 11,
        user_id: 1,
        notification_type: NOTIFICATION_TYPES.group_mentioned,
        read: false,
        high_priority: false,
        created_at: "2022-07-01T06:00:32.173Z",
        post_number: 113,
        topic_id: 449,
        fancy_title: "This is fancy title &lt;a&gt;!",
        slug: "this-is-fancy-title",
        data: {
          topic_title: "this is title before it becomes fancy <a>!",
          original_post_id: 112,
          original_post_type: 1,
          original_username: "kolary",
          display_username: "osama",
          group_id: 333,
          group_name: "hikers",
        },
      },
      overrides
    )
  );
}

module("Unit | Notification Types | group-mentioned", function (hooks) {
  setupTest(hooks);

  test("label", function (assert) {
    const notification = getNotification();
    const director = createRenderDirector(
      notification,
      "group_mentioned",
      this.siteSettings
    );
    assert.strictEqual(
      director.label,
      "osama @hikers",
      "contains the user who mentioned and the mentioned group"
    );
  });
});
