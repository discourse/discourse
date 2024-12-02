import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Managing Group Profile", function () {
  test("As an anonymous user", async function (assert) {
    await visit("/g/discourse/manage/profile");

    assert
      .dom(".group-members .group-member")
      .exists("it should redirect to members page for an anonymous user");
  });
});

acceptance("Managing Group Profile", function (needs) {
  needs.user();

  test("As an admin", async function (assert) {
    await visit("/g/discourse/manage/profile");

    assert.dom(".group-form-bio").exists("displays group bio input");
    assert.dom(".group-form-name").exists("displays group name input");
    assert
      .dom(".group-form-full-name")
      .exists("displays group full name input");
  });

  test("As a group owner", async function (assert) {
    updateCurrentUser({
      moderator: false,
      admin: false,
      can_create_group: false,
    });

    await visit("/g/discourse/manage/profile");

    assert
      .dom(".group-form-name")
      .doesNotExist("it should not display group name input");
  });
});
