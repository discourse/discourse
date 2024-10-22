import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  count,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

acceptance("New Group - Anonymous", function () {
  test("As an anon user", async function (assert) {
    await visit("/g");

    assert
      .dom(".groups-header-new")
      .doesNotExist("it should not display the button to create a group");
  });
});

acceptance("New Group - Authenticated", function (needs) {
  needs.user();

  test("Creating a new group", async function (assert) {
    await visit("/g");
    await click(".groups-header-new");

    assert.strictEqual(
      count(".group-form-save[disabled]"),
      1,
      "save button should be disabled"
    );

    await fillIn("input[name='name']", "1");

    assert
      .dom(".tip.bad")
      .hasText(
        I18n.t("admin.groups.new.name.too_short"),
        "it should show the right validation tooltip"
      );

    assert.strictEqual(
      count(".group-form-save:disabled"),
      1,
      "it should disable the save button"
    );

    await fillIn(
      "input[name='name']",
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    );

    assert
      .dom(".tip.bad")
      .hasText(
        I18n.t("admin.groups.new.name.too_long"),
        "it should show the right validation tooltip"
      );

    await fillIn("input[name='name']", "");

    assert
      .dom(".tip.bad")
      .hasText(
        I18n.t("admin.groups.new.name.blank"),
        "it should show the right validation tooltip"
      );

    await fillIn("input[name='name']", "good-username");

    assert
      .dom(".tip.good")
      .hasText(
        I18n.t("admin.groups.new.name.available"),
        "it should show the right validation tooltip"
      );

    await click(".group-form-public-admission");

    assert
      .dom("groups-new-allow-membership-requests")
      .doesNotExist("it should disable the membership requests checkbox");

    assert.strictEqual(
      query(
        ".groups-form-default-notification-level .selected-name .name"
      ).innerText.trim(),
      I18n.t("groups.notifications.watching.title"),
      "it has a default selection for notification level"
    );
  });
});
