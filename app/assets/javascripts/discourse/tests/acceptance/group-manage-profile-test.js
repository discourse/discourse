import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
  count,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Managing Group Profile", function () {
  test("As an anonymous user", async (assert) => {
    await visit("/g/discourse/manage/profile");

    assert.ok(
      count(".group-members tr") > 0,
      "it should redirect to members page for an anonymous user"
    );
  });
});

acceptance("Managing Group Profile", function (needs) {
  needs.user();

  test("As an admin", async (assert) => {
    await visit("/g/discourse/manage/profile");

    assert.ok(
      find(".group-flair-inputs").length === 1,
      "it should display avatar flair inputs"
    );
    assert.ok(
      find(".group-form-bio").length === 1,
      "it should display group bio input"
    );
    assert.ok(
      find(".group-form-name").length === 1,
      "it should display group name input"
    );
    assert.ok(
      find(".group-form-full-name").length === 1,
      "it should display group full name input"
    );
  });

  test("As a group owner", async (assert) => {
    updateCurrentUser({
      moderator: false,
      admin: false,
      can_create_group: false,
    });

    await visit("/g/discourse/manage/profile");

    assert.equal(
      find(".group-form-name").length,
      0,
      "it should not display group name input"
    );
  });
});
