import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Managing Group Category Notification Defaults", function () {
  test("As an anonymous user", async function (assert) {
    await visit("/g/discourse/manage/categories");

    assert
      .dom(".group-members .group-member")
      .exists("it should redirect to members page for an anonymous user");
  });
});

acceptance("Managing Group Category Notification Defaults", function (needs) {
  needs.user();
  test("As an admin", async function (assert) {
    await visit("/g/discourse/manage/categories");

    assert
      .dom(".groups-notifications-form .category-selector")
      .exists({ count: 5 }, "displays category inputs");
  });

  test("As a group owner", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/g/discourse/manage/categories");

    assert
      .dom(".groups-notifications-form .category-selector")
      .exists({ count: 5 }, "displays category inputs");
  });
});
