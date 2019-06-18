import { acceptance } from "helpers/qunit-helpers";

acceptance("New Group");

QUnit.test("As an anon user", async assert => {
  await visit("/g");

  assert.equal(
    find(".groups-header-new").length,
    0,
    "it should not display the button to create a group"
  );
});

acceptance("New Group", { loggedIn: true });

QUnit.test("Creating a new group", async assert => {
  await visit("/g");
  await click(".groups-header-new");

  assert.equal(
    find(".group-form-save[disabled]").length,
    1,
    "save button should be disabled"
  );

  await fillIn("input[name='name']", "1");

  assert.equal(
    find(".tip.bad")
      .text()
      .trim(),
    I18n.t("admin.groups.new.name.too_short"),
    "it should show the right validation tooltip"
  );

  assert.ok(
    find(".group-form-save:disabled").length === 1,
    "it should disable the save button"
  );

  await fillIn(
    "input[name='name']",
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  );

  assert.equal(
    find(".tip.bad")
      .text()
      .trim(),
    I18n.t("admin.groups.new.name.too_long"),
    "it should show the right validation tooltip"
  );

  await fillIn("input[name='name']", "");

  assert.equal(
    find(".tip.bad")
      .text()
      .trim(),
    I18n.t("admin.groups.new.name.blank"),
    "it should show the right validation tooltip"
  );

  await fillIn("input[name='name']", "goodusername");

  assert.equal(
    find(".tip.good")
      .text()
      .trim(),
    I18n.t("admin.groups.new.name.available"),
    "it should show the right validation tooltip"
  );

  await click(".group-form-public-admission");

  assert.equal(
    find("groups-new-allow-membership-requests").length,
    0,
    "it should disable the membership requests checkbox"
  );
});
