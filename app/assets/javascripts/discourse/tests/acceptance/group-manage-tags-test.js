import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Managing Group Tag Notification Defaults");
QUnit.test("As an anonymous user", async (assert) => {
  await visit("/g/discourse/manage/tags");

  assert.ok(
    count(".group-members tr") > 0,
    "it should redirect to members page for an anonymous user"
  );
});

acceptance("Managing Group Tag Notification Defaults", { loggedIn: true });

QUnit.test("As an admin", async (assert) => {
  await visit("/g/discourse/manage/tags");

  assert.ok(
    find(".groups-notifications-form .tag-chooser").length === 5,
    "it should display tag inputs"
  );
});

QUnit.test("As a group owner", async (assert) => {
  updateCurrentUser({ moderator: false, admin: false });

  await visit("/g/discourse/manage/tags");

  assert.ok(
    find(".groups-notifications-form .tag-chooser").length === 5,
    "it should display tag inputs"
  );
});
