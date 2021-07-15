import { visit } from "@ember/test-helpers";
import {
  acceptance,
  count,
  publishToMessageBus,
  query,
  queryAll,
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

    assert.equal(count("#quick-access-notifications li"), 5);

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

    assert.equal(count("#quick-access-notifications li"), 6);
    assert.equal(
      query("#quick-access-notifications li span[data-topic-id]").innerText,
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

    assert.equal(count("#quick-access-notifications li"), 7);
    assert.equal(
      queryAll("#quick-access-notifications li span[data-topic-id]")[1]
        .innerText,
      "Second notification"
    );

    // updates existing notifications

    publishToMessageBus("/notification/19", {
      unread_notifications: 8,
      unread_private_messages: 0,
      unread_high_priority_notifications: 1,
      read_first_notification: false,
      last_notification: {
        notification: {
          id: 44,
          user_id: 1,
          notification_type: 5,
          high_priority: true,
          read: true,
          high_priority: false,
          created_at: "2021-01-01 12:00:00 UTC",
          post_number: 1,
          topic_id: 42,
          fancy_title: "Third notification",
          slug: "topic",
          data: {
            topic_title: "Third notification",
            original_post_id: 42,
            original_post_type: 1,
            original_username: "foo",
            revision_number: null,
            display_username: "foo",
          },
        },
      },
      recent: [
        [5678, false],
        [1234, false],
        [789, false],
        [456, true],
        [123, true],
        [44, false],
        [43, false],
        [42, true],
      ],
      seen_notification_id: null,
    });

    await visit("/"); // wait for re-render
    assert.equal(count("#quick-access-notifications li"), 8);
    const texts = [];
    queryAll("#quick-access-notifications li").each((_, el) =>
      texts.push(el.innerText.trim())
    );
    assert.deepEqual(texts, [
      "foo First notification",
      "foo Third notification",
      "foo Second notification",
      "velesin some title",
      "aquaman liked 5 of your posts",
      "5 messages in your test inbox",
      "test1 accepted your invitation",
      "Membership accepted in 'test'",
    ]);
  });
});
