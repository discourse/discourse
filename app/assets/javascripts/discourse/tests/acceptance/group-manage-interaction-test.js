import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

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

    assert
      .dom(".groups-form-visibility-level")
      .exists("displays visibility level selector");

    assert
      .dom(".groups-form-mentionable-level")
      .exists("displays mentionable level selector");

    assert
      .dom(".groups-form-messageable-level")
      .exists("displays messageable level selector");

    assert
      .dom(".groups-form-incoming-email")
      .exists("displays incoming email input");

    assert
      .dom(".groups-form-default-notification-level")
      .exists("displays default notification level input");
  });

  test("As a group owner", async function (assert) {
    updateCurrentUser({
      moderator: false,
      admin: false,
      can_create_group: false,
    });

    await visit("/g/discourse/manage/interaction");

    assert
      .dom(".groups-form-visibility-level")
      .doesNotExist("does not display visibility level selector");

    assert
      .dom(".groups-form-mentionable-level")
      .exists("displays mentionable level selector");

    assert
      .dom(".groups-form-messageable-level")
      .exists("displays messageable level selector");

    assert
      .dom(".groups-form-incoming-email")
      .doesNotExist("does not display incoming email input");

    assert
      .dom(".groups-form-default-notification-level")
      .exists("displays default notification level input");
  });
});

acceptance(
  "Managing Group Interaction Settings - Notification Levels",
  function (needs) {
    needs.user({ admin: true });

    test("For a group with a default_notification_level of 0", async function (assert) {
      await visit("/g/alternative-group/manage/interaction");

      await assert.dom(".groups-form").exists("has the form");
      await assert.strictEqual(
        selectKit(".groups-form-default-notification-level").header().value(),
        "0",
        "it should select Muted as the notification level"
      );
    });

    test("For a group with a null default_notification_level", async function (assert) {
      await visit("/g/discourse/manage/interaction");

      await assert.dom(".groups-form").exists("has the form");
      await assert.strictEqual(
        selectKit(".groups-form-default-notification-level").header().value(),
        "3",
        "it should select Watching as the notification level"
      );
    });

    test("For a group with a selected default_notification_level", async function (assert) {
      await visit("/g/support/manage/interaction");

      await assert.dom(".groups-form").exists("has the form");
      await assert.strictEqual(
        selectKit(".groups-form-default-notification-level").header().value(),
        "2",
        "it should select Tracking as the notification level"
      );
    });
  }
);
