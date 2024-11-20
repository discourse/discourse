import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

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

    assert.dom(".group-form-save").isDisabled("save button is disabled");

    await fillIn("input[name='name']", "1");

    assert
      .dom(".tip.bad")
      .hasText(
        i18n("admin.groups.new.name.too_short"),
        "it should show the right validation tooltip"
      );

    assert.dom(".group-form-save").isDisabled("disables the save button");

    await fillIn(
      "input[name='name']",
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    );

    assert
      .dom(".tip.bad")
      .hasText(
        i18n("admin.groups.new.name.too_long"),
        "it should show the right validation tooltip"
      );

    await fillIn("input[name='name']", "");

    assert
      .dom(".tip.bad")
      .hasText(
        i18n("admin.groups.new.name.blank"),
        "it should show the right validation tooltip"
      );

    await fillIn("input[name='name']", "good-username");

    assert
      .dom(".tip.good")
      .hasText(
        i18n("admin.groups.new.name.available"),
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
      i18n("groups.notifications.watching.title"),
      "it has a default selection for notification level"
    );
  });
});
