import {
  acceptance,
  count,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import I18n from "I18n";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";

acceptance("Category Edit - security", function (needs) {
  needs.user();

  test("default", async function (assert) {
    await visit("/c/bug/edit/security");

    const firstRow = queryAll(".row-body").first();
    const badgeName = firstRow.find(".group-name-label").text();
    assert.equal(badgeName, "everyone");

    const permission = firstRow.find(".d-icon-check-square");
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
      queryAll(".row-empty").text(),
      I18n.t("category.permissions.no_groups_selected"),
      "shows message when no groups are selected"
    );
  });

  test("adding a permission", async function (assert) {
    const availableGroups = selectKit(".available-groups");

    await visit("/c/bug/edit/security");

    await availableGroups.expand();
    await availableGroups.selectRowByValue("staff");

    const addedRow = queryAll(".row-body").last();

    assert.equal(addedRow.find(".group-name-label").text(), "staff");
    assert.equal(
      addedRow.find(".d-icon-check-square").length,
      3,
      "new row permissions match default 'everyone' permissions"
    );
  });

  test("adding a previously removed permission", async function (assert) {
    const availableGroups = selectKit(".available-groups");

    await visit("/c/bug/edit/security");

    await click(".row-body .remove-permission");

    assert.ok(!exists(".row-body"), "removes the permission from the list");

    await availableGroups.expand();
    await availableGroups.selectRowByValue("everyone");

    assert.equal(count(".row-body"), 1, "adds back the permission tp the list");

    const firstRow = queryAll(".row-body").first();

    assert.equal(firstRow.find(".group-name-label").text(), "everyone");
    assert.equal(
      firstRow.find(".d-icon-check-square").length,
      1,
      "adds only 'See' permission for a new row"
    );
  });

  test("editing permissions", async function (assert) {
    const availableGroups = selectKit(".available-groups");

    await visit("/c/bug/edit/security");

    const everyoneRow = queryAll(".row-body").first();

    assert.equal(
      everyoneRow.find(".reply-granted, .create-granted").length,
      2,
      "everyone has full permissions by default"
    );

    await availableGroups.expand();
    await availableGroups.selectRowByValue("staff");

    const staffRow = queryAll(".row-body").last();

    assert.equal(
      staffRow.find(".reply-granted, .create-granted").length,
      2,
      "staff group also has full permissions"
    );

    await click(everyoneRow.find(".reply-toggle")[0]);

    assert.equal(
      everyoneRow.find(".reply-granted, .create-granted").length,
      0,
      "everyone does not have reply or create"
    );

    assert.equal(
      staffRow.find(".reply-granted, .create-granted").length,
      2,
      "staff group still has full permissions"
    );

    await click(staffRow.find(".reply-toggle")[0]);

    assert.equal(
      everyoneRow.find(".reply-granted, .create-granted").length,
      0,
      "everyone permission unchanged"
    );

    assert.equal(
      staffRow.find(".reply-granted").length,
      0,
      "staff does not have reply permission"
    );

    assert.equal(
      staffRow.find(".create-granted").length,
      0,
      "staff does not have create permission"
    );

    await click(everyoneRow.find(".create-toggle")[0]);

    assert.equal(
      everyoneRow.find(".reply-granted, .create-granted").length,
      2,
      "everyone has full permissions"
    );

    assert.equal(
      staffRow.find(".reply-granted, .create-granted").length,
      2,
      "staff group has full permissions (inherited from everyone)"
    );
  });
});
