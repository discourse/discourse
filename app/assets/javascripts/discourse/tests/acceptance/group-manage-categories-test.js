import {
  acceptance,
  count,
  exists,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Managing Group Category Notification Defaults", function () {
  test("As an anonymous user", async function (assert) {
    await visit("/g/discourse/manage/categories");

    assert.ok(
      exists(".group-members .group-member"),
      "it should redirect to members page for an anonymous user"
    );
  });
});

acceptance("Managing Group Category Notification Defaults", function (needs) {
  needs.user();
  test("As an admin", async function (assert) {
    await visit("/g/discourse/manage/categories");

    assert.strictEqual(
      count(".groups-notifications-form .category-selector"),
      5,
      "it should display category inputs"
    );
  });

  test("As a group owner", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/g/discourse/manage/categories");

    assert.strictEqual(
      count(".groups-notifications-form .category-selector"),
      5,
      "it should display category inputs"
    );
  });
});
