import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
  count,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Managing Group Category Notification Defaults", function () {
  test("As an anonymous user", async (assert) => {
    await visit("/g/discourse/manage/categories");

    assert.ok(
      count(".group-members tr") > 0,
      "it should redirect to members page for an anonymous user"
    );
  });
});

acceptance("Managing Group Category Notification Defaults", function (needs) {
  needs.user();
  test("As an admin", async (assert) => {
    await visit("/g/discourse/manage/categories");

    assert.ok(
      find(".groups-notifications-form .category-selector").length === 5,
      "it should display category inputs"
    );
  });

  test("As a group owner", async (assert) => {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/g/discourse/manage/categories");

    assert.ok(
      find(".groups-notifications-form .category-selector").length === 5,
      "it should display category inputs"
    );
  });
});
