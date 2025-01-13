import { getOwner } from "@ember/owner";
import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import NotificationFixtures from "discourse/tests/fixtures/notification-fixtures";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Category Notifications", function (needs) {
  needs.user({ muted_category_ids: [1], indirectly_muted_category_ids: [2] });

  test("New category is muted when parent category is muted", async function (assert) {
    await visit("/");
    const user = getOwner(this).lookup("service:current-user");

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
  "User Notifications - there are no notifications yet",
  function (needs) {
    needs.user();

    needs.pretender((server, helper) => {
      server.get("/notifications", () => {
        return helper.response({
          notifications: [],
        });
      });
    });

    test("renders the empty state panel", async function (assert) {
      await visit("/u/eviltrout/notifications");

      assert.dom("div.empty-state").exists();
      assert.dom("div.user-notifications-filter").doesNotExist();
    });
  }
);

acceptance("User Notifications", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/notifications", () => {
      return helper.response(cloneJSON(NotificationFixtures["/notifications"]));
    });
  });

  test("shows the notifications list", async function (assert) {
    await visit("/u/eviltrout/notifications");

    assert.dom("div.empty-state").doesNotExist();
    assert.dom("div.user-notifications-filter").exists();
    assert
      .dom(".user-notifications-list .notification.unread")
      .exists({ count: 6 });

    await click(".notification.liked-consolidated a");
    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/notifications/likes-received?acting_username=aquaman"
    );
  });
});
