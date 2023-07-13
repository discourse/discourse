import { visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import User from "discourse/models/user";

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
