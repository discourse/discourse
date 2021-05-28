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

    // set older notifications to read

    publishToMessageBus("/notification/19", {
      unread_notifications: 5,
      unread_private_messages: 0,
      unread_high_priority_notifications: 0,
      read_first_notification: false,
      last_notification: {},
      recent: [
        [123, false],
        [456, false],
        [789, true],
        [1234, true],
        [5678, true],
      ],
      seen_notification_id: null,
    });

    await visit("/"); // wait for re-render

    assert.equal(find("#quick-access-notifications li").length, 5);

    // high priority, unread notification - should be first

    publishToMessageBus("/notification/19", {
      unread_notifications: 6,
      unread_private_messages: 0,
      unread_high_priority_notifications: 1,
      read_first_notification: false,
      last_notification: {
        notification: {
          id: 42,
          user_id: 1,
          notification_type: 5,
          high_priority: true,
          read: false,
          high_priority: true,
          created_at: "2021-01-01 12:00:00 UTC",
          post_number: 1,
          topic_id: 42,
          fancy_title: "First notification",
          slug: "topic",
          data: {
            topic_title: "First notification",
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
        [789, true],
        [1234, true],
        [5678, true],
      ],
      seen_notification_id: null,
    });

    await visit("/"); // wait for re-render

    assert.equal(find("#quick-access-notifications li").length, 6);
    assert.equal(
      find("#quick-access-notifications li span[data-topic-id]")[0].innerText,
      "First notification"
    );

    // high priority, read notification - should be second

    publishToMessageBus("/notification/19", {
      unread_notifications: 7,
      unread_private_messages: 0,
      unread_high_priority_notifications: 1,
      read_first_notification: false,
      last_notification: {
        notification: {
          id: 43,
          user_id: 1,
          notification_type: 5,
          high_priority: true,
          read: true,
          high_priority: false,
          created_at: "2021-01-01 12:00:00 UTC",
          post_number: 1,
          topic_id: 42,
          fancy_title: "Second notification",
          slug: "topic",
          data: {
            topic_title: "Second notification",
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
        [43, true],
        [123, false],
        [456, false],
        [789, true],
        [1234, true],
        [5678, true],
      ],
      seen_notification_id: null,
    });

    await visit("/"); // wait for re-render

    assert.equal(find("#quick-access-notifications li").length, 7);
    assert.equal(
      find("#quick-access-notifications li span[data-topic-id]")[1].innerText,
      "Second notification"
    );
  });
});
