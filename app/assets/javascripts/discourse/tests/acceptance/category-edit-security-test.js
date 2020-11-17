import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";

acceptance("Category Edit - security", function (needs) {
  needs.user();

  test("default", async function (assert) {
    await visit("/c/bug/edit/security");

    const firstRow = find(".row-body").first();
    const badgeName = firstRow.find(".group-name-label").text();
    assert.equal(badgeName, "everyone");

    const permission = firstRow.find(".d-icon-check");
    assert.equal(permission.length, 3);
  });

  test("removing a permission", async function (assert) {
    const availableGroups = selectKit(".available-groups");

    await visit("/c/bug/edit/security");

    await availableGroups.expand();
    assert.notOk(
      availableGroups.rowByValue("everyone").exists(),
      "everyone is already used and is not in the available groups"
    );

    await click(".row-body .remove-permission");
    await availableGroups.expand();

    assert.ok(
      availableGroups.rowByValue("everyone").exists(),
      "everyone has been removed and appears in the available groups"
    );
    assert.ok(
      find(".row-empty").text(),
      I18n.t("category.permissions.no_groups_selected"),
      "shows message when no groups are selected"
    );
  });

  test("adding a permission", async function (assert) {
    const availableGroups = selectKit(".available-groups");

    await visit("/c/bug/edit/security");

    await availableGroups.expand();
    await availableGroups.selectRowByValue("staff");

    const addedRow = find(".row-body").last();

    assert.equal(addedRow.find(".group-name-label").text(), "staff");
    assert.equal(
      addedRow.find(".d-icon-check").length,
      3,
      "new row permissions match default 'everyone' permissions"
    );
  });

  test("adding a previously removed permission", async function (assert) {
    const availableGroups = selectKit(".available-groups");

    await visit("/c/bug/edit/security");

    await click(".row-body .remove-permission");

    assert.equal(
      find(".row-body").length,
      0,
      "removes the permission from the list"
    );

    await availableGroups.expand();
    await availableGroups.selectRowByValue("everyone");

    assert.equal(
      find(".row-body").length,
      1,
      "adds back the permission tp the list"
    );

    const firstRow = find(".row-body").first();

    assert.equal(firstRow.find(".group-name-label").text(), "everyone");
    assert.equal(
      firstRow.find(".d-icon-check").length,
      1,
      "adds only 'See' permission for a new row"
    );
  });

  test("editing permissions", async function (assert) {
    const availableGroups = selectKit(".available-groups");

    await visit("/c/bug/edit/security");

    const everyoneRow = find(".row-body").first();

    assert.equal(
      everyoneRow.find(".d-icon-check").length,
      3,
      "everyone has full permissions"
    );

    await availableGroups.expand();
    await availableGroups.selectRowByValue("staff");

    const staffRow = find(".row-body").last();

    assert.equal(
      staffRow.find(".d-icon-check").length,
      3,
      "staff group also has full permissions"
    );

    await click(everyoneRow.find(".btn.see"));

    assert.equal(
      everyoneRow.find(".see .d-icon-check").length,
      1,
      "everyone has see permission"
    );

    assert.equal(
      everyoneRow.find(".d-icon-times").length,
      2,
      "everyone does not have reply or create"
    );

    assert.equal(
      staffRow.find(".d-icon-check").length,
      3,
      "staff group still has full permissions"
    );

    await click(staffRow.find(".btn.reply"));

    assert.equal(
      everyoneRow.find(".d-icon-check").length,
      1,
      "everyone permission unchanged"
    );

    assert.equal(
      staffRow.find(".see .d-icon-check, .reply .d-icon-check").length,
      2,
      "staff group has see and reply permissions"
    );

    assert.equal(
      staffRow.find(".create .d-icon-times").length,
      1,
      "staff does not have create permissions"
    );

    await click(everyoneRow.find(".btn.create"));

    assert.equal(
      everyoneRow.find(".d-icon-check").length,
      3,
      "everyone has full permissions"
    );

    assert.equal(
      staffRow.find(".d-icon-check").length,
      3,
      "staff group has full permissions (inherited from everyone)"
    );
  });
});
