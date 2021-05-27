import { visit } from "@ember/test-helpers";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

acceptance("User Notifications", function (needs) {
  needs.user();

  test("Update works correctly", async function (assert) {
    await visit("/");
    await click("li.current-user");

    publishToMessageBus("/notification/19", {
      unread_notifications: 5,
      unread_private_messages: 1,
      unread_high_priority_notifications: 1,
      read_first_notification: false,
      last_notification: {
        notification: {
          id: 42,
          user_id: 1,
          notification_type: 5,
          high_priority: true,
          read: false,
          high_priority: false,
          created_at: "2021-01-01 12:00:00 UTC",
          post_number: 1,
          topic_id: 42,
          fancy_title: "A new notification",
          slug: "a-new-notification",
          data: {
            topic_title: "A new notification",
            original_post_id: 42,
            original_post_type: 1,
            original_username: "foo",
            revision_number: null,
            display_username: "foo",
          },
        },
      },
      recent: [
        [42, false],
        [123, false],
        [456, false],
        [789, false],
        [1234, false],
        [5678, false],
      ],
      seen_notification_id: null,
    });

    await visit("/"); // wait for re-render

    assert.equal(find("#quick-access-notifications li").length, 6);
    assert.equal(
      find("#quick-access-notifications li span[data-topic-id]")[0].innerText,
      "A new notification"
    );
  });
});
