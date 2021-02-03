import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import I18n from "I18n";
import { test } from "qunit";

acceptance("New Group - Anonymous", function () {
  test("As an anon user", async function (assert) {
    await visit("/g");

    assert.equal(
      queryAll(".groups-header-new").length,
      0,
      "it should not display the button to create a group"
    );
  });
});

acceptance("New Group - Authenticated", function (needs) {
  needs.user();
  test("Creating a new group", async function (assert) {
    await visit("/g");
    await click(".groups-header-new");

    assert.equal(
      queryAll(".group-form-save[disabled]").length,
      1,
      "save button should be disabled"
    );

    await fillIn("input[name='name']", "1");

    assert.equal(
      queryAll(".tip.bad").text().trim(),
      I18n.t("admin.groups.new.name.too_short"),
      "it should show the right validation tooltip"
    );

    assert.ok(
      queryAll(".group-form-save:disabled").length === 1,
      "it should disable the save button"
    );

    await fillIn(
      "input[name='name']",
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    );

    assert.equal(
      queryAll(".tip.bad").text().trim(),
      I18n.t("admin.groups.new.name.too_long"),
      "it should show the right validation tooltip"
    );

    await fillIn("input[name='name']", "");

    assert.equal(
      queryAll(".tip.bad").text().trim(),
      I18n.t("admin.groups.new.name.blank"),
      "it should show the right validation tooltip"
    );

    await fillIn("input[name='name']", "goodusername");

    assert.equal(
      queryAll(".tip.good").text().trim(),
      I18n.t("admin.groups.new.name.available"),
      "it should show the right validation tooltip"
    );

    await click(".group-form-public-admission");

    assert.equal(
      queryAll("groups-new-allow-membership-requests").length,
      0,
      "it should disable the membership requests checkbox"
    );

    assert.ok(
      queryAll(".groups-form-default-notification-level .selected-name .name")
        .text()
        .trim() === I18n.t("groups.notifications.watching.title"),
      "it has a default selection for notification level"
    );
  });
});
