import { click, visit } from "@ember/test-helpers";
import {
  acceptance,
  count,
  exists,
  publishToMessageBus,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import User from "discourse/models/user";

acceptance("User Notifications", function (needs) {
  needs.user();

  test("Update works correctly", async function (assert) {
    await visit("/");
    await click("li.current-user");

    // set older notifications to read

    await publishToMessageBus("/notification/19", {
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

    assert.strictEqual(count("#quick-access-notifications li"), 6);

    // high priority, unread notification - should be first

    await publishToMessageBus("/notification/19", {
      unread_notifications: 6,
      unread_private_messages: 0,
      unread_high_priority_notifications: 1,
      read_first_notification: false,
      last_notification: {
        notification: {
          id: 42,
          user_id: 1,
          notification_type: 5,
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

    assert.strictEqual(count("#quick-access-notifications li"), 6);
    assert.strictEqual(
      query("#quick-access-notifications li span[data-topic-id]").innerText,
      "First notification"
    );

    // high priority, read notification - should be second

    await publishToMessageBus("/notification/19", {
      unread_notifications: 7,
      unread_private_messages: 0,
      unread_high_priority_notifications: 1,
      read_first_notification: false,
      last_notification: {
        notification: {
          id: 43,
          user_id: 1,
          notification_type: 5,
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

    assert.strictEqual(count("#quick-access-notifications li"), 7);
    assert.strictEqual(
      queryAll("#quick-access-notifications li span[data-topic-id]")[1]
        .innerText,
      "Second notification"
    );

    // updates existing notifications

    await publishToMessageBus("/notification/19", {
      unread_notifications: 8,
      unread_private_messages: 0,
      unread_high_priority_notifications: 1,
      read_first_notification: false,
      last_notification: {
        notification: {
          id: 44,
          user_id: 1,
          notification_type: 5,
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

    assert.strictEqual(count("#quick-access-notifications li"), 8);
    const texts = [];
    [...queryAll("#quick-access-notifications li")].forEach((element) => {
      texts.push(element.innerText.trim());
    });
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

acceptance("Category Notifications", function (needs) {
  needs.user({ muted_category_ids: [1], indirectly_muted_category_ids: [2] });

  test("New category is muted when parent category is muted", async function (assert) {
    await visit("/");
    const user = User.current();
    await publishToMessageBus("/categories", {
      categories: [
        {
          id: 3,
          parent_category_id: 99,
        },
        {
          id: 4,
        },
      ],
    });
    assert.deepEqual(user.indirectly_muted_category_ids, [2]);

    await publishToMessageBus("/categories", {
      categories: [
        {
          id: 4,
          parent_category_id: 1,
        },
        {
          id: 5,
          parent_category_id: 2,
        },
      ],
    });
    assert.deepEqual(user.indirectly_muted_category_ids, [2, 4, 5]);
  });
});

acceptance(
  "User Notifications - there is no notifications yet",
  function (needs) {
    needs.user();

    needs.pretender((server, helper) => {
      server.get("/notifications", () => {
        return helper.response({
          notifications: [],
        });
      });
    });

    test("It renders the empty state panel", async function (assert) {
      await visit("/u/eviltrout/notifications");
      assert.ok(exists("div.empty-state"));
    });

    test("It does not render filter", async function (assert) {
      await visit("/u/eviltrout/notifications");

      assert.notOk(exists("div.user-notifications-filter"));
    });
  }
);
