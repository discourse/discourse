import {
  acceptance,
  count,
  exists,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Managing Group Tag Notification Defaults", function () {
  test("As an anonymous user", async function (assert) {
    await visit("/g/discourse/manage/tags");

    assert.ok(
      exists(".group-members tr"),
      "it should redirect to members page for an anonymous user"
    );
  });
});

acceptance("Managing Group Tag Notification Defaults", function (needs) {
  needs.user();

  test("As an admin", async function (assert) {
    await visit("/g/discourse/manage/tags");

    assert.equal(
      count(".groups-notifications-form .tag-chooser"),
      5,
      "it should display tag inputs"
    );
  });

  test("As a group owner", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/g/discourse/manage/tags");

    assert.equal(
      count(".groups-notifications-form .tag-chooser"),
      5,
      "it should display tag inputs"
    );
  });
});
