import {
  acceptance,
  queryAll,
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
      queryAll(".groups-form-visibility-level").length,
      1,
      "it should display visibility level selector"
    );

    assert.equal(
      queryAll(".groups-form-mentionable-level").length,
      1,
      "it should display mentionable level selector"
    );

    assert.equal(
      queryAll(".groups-form-messageable-level").length,
      1,
      "it should display messageable level selector"
    );

    assert.equal(
      queryAll(".groups-form-incoming-email").length,
      1,
      "it should display incoming email input"
    );

    assert.equal(
      queryAll(".groups-form-default-notification-level").length,
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
      queryAll(".groups-form-visibility-level").length,
      0,
      "it should not display visibility level selector"
    );

    assert.equal(
      queryAll(".groups-form-mentionable-level").length,
      1,
      "it should display mentionable level selector"
    );

    assert.equal(
      queryAll(".groups-form-messageable-level").length,
      1,
      "it should display messageable level selector"
    );

    assert.equal(
      queryAll(".groups-form-incoming-email").length,
      0,
      "it should not display incoming email input"
    );

    assert.equal(
      queryAll(".groups-form-default-notification-level").length,
      1,
      "it should display default notification level input"
    );
  });
});
