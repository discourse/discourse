import {
  acceptance,
  count,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Managing Group Interaction Settings", function (needs) {
  needs.user();
  needs.settings({ email_in: true });

  test("As an admin", async function (assert) {
    updateCurrentUser({
      moderator: false,
      admin: true,
      can_create_group: true,
    });

    await visit("/g/alternative-group/manage/interaction");

    assert.equal(
      count(".groups-form-visibility-level"),
      1,
      "it should display visibility level selector"
    );

    assert.equal(
      count(".groups-form-mentionable-level"),
      1,
      "it should display mentionable level selector"
    );

    assert.equal(
      count(".groups-form-messageable-level"),
      1,
      "it should display messageable level selector"
    );

    assert.equal(
      count(".groups-form-incoming-email"),
      1,
      "it should display incoming email input"
    );

    assert.equal(
      count(".groups-form-default-notification-level"),
      1,
      "it should display default notification level input"
    );
  });

  test("As a group owner", async function (assert) {
    updateCurrentUser({
      moderator: false,
      admin: false,
      can_create_group: false,
    });

    await visit("/g/discourse/manage/interaction");

    assert.equal(
      count(".groups-form-visibility-level"),
      0,
      "it should not display visibility level selector"
    );

    assert.equal(
      count(".groups-form-mentionable-level"),
      1,
      "it should display mentionable level selector"
    );

    assert.equal(
      count(".groups-form-messageable-level"),
      1,
      "it should display messageable level selector"
    );

    assert.equal(
      count(".groups-form-incoming-email"),
      0,
      "it should not display incoming email input"
    );

    assert.equal(
      count(".groups-form-default-notification-level"),
      1,
      "it should display default notification level input"
    );
  });
});
