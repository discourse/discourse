import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  count,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "discourse-i18n";

acceptance("Category Edit - Security", function (needs) {
  needs.user();

  test("default", async function (assert) {
    await visit("/c/bug/edit/security");

    const firstRow = query(".row-body");
    const badgeName = firstRow.querySelector(".group-name-label").innerText;
    assert.strictEqual(badgeName, "everyone");

    assert.strictEqual(count(".d-icon-square-check"), 3);
  });

  test("removing a permission", async function (assert) {
    const availableGroups = selectKit(".available-groups");

    await visit("/c/bug/edit/security");

    await availableGroups.expand();
    assert.false(
      availableGroups.rowByValue("everyone").exists(),
      "everyone is already used and is not in the available groups"
    );

    await click(".row-body .remove-permission");
    await availableGroups.expand();

    assert.ok(
      availableGroups.rowByValue("everyone").exists(),
      "everyone has been removed and appears in the available groups"
    );
    assert
      .dom(".row-empty")
      .hasText(
        I18n.t("category.permissions.no_groups_selected"),
        "shows message when no groups are selected"
      );
  });

  test("adding a permission", async function (assert) {
    const availableGroups = selectKit(".available-groups");

    await visit("/c/bug/edit/security");

    await availableGroups.expand();
    await availableGroups.selectRowByValue("staff");

    const addedRow = [...queryAll(".row-body")].at(-1);

    assert.strictEqual(
      addedRow.querySelector(".group-name-link").innerText,
      "staff"
    );
    assert.strictEqual(
      addedRow.querySelectorAll(".d-icon-square-check").length,
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

    assert.strictEqual(
      count(".row-body"),
      1,
      "adds back the permission tp the list"
    );

    const firstRow = query(".row-body");

    assert.strictEqual(
      firstRow.querySelector(".group-name-label").innerText,
      "everyone"
    );
    assert.strictEqual(
      firstRow.querySelectorAll(".d-icon-square-check").length,
      1,
      "adds only 'See' permission for a new row"
    );
  });

  test("editing permissions", async function (assert) {
    const availableGroups = selectKit(".available-groups");

    await visit("/c/bug/edit/security");

    const everyoneRow = query(".row-body");

    assert.strictEqual(
      everyoneRow.querySelectorAll(".reply-granted, .create-granted").length,
      2,
      "everyone has full permissions by default"
    );

    await availableGroups.expand();
    await availableGroups.selectRowByValue("staff");

    const staffRow = [...queryAll(".row-body")].at(-1);

    assert.strictEqual(
      staffRow.querySelectorAll(".reply-granted, .create-granted").length,
      2,
      "staff group also has full permissions"
    );

    await click(everyoneRow.querySelector(".reply-toggle"));

    assert.strictEqual(
      everyoneRow.querySelectorAll(".reply-granted, .create-granted").length,
      0,
      "everyone does not have reply or create"
    );

    assert.strictEqual(
      staffRow.querySelectorAll(".reply-granted, .create-granted").length,
      2,
      "staff group still has full permissions"
    );

    await click(staffRow.querySelector(".reply-toggle"));

    assert.strictEqual(
      everyoneRow.querySelectorAll(".reply-granted, .create-granted").length,
      0,
      "everyone permission unchanged"
    );

    assert.strictEqual(
      staffRow.querySelectorAll(".reply-granted").length,
      0,
      "staff does not have reply permission"
    );

    assert.strictEqual(
      staffRow.querySelectorAll(".create-granted").length,
      0,
      "staff does not have create permission"
    );

    await click(everyoneRow.querySelector(".create-toggle"));

    assert.strictEqual(
      everyoneRow.querySelectorAll(".reply-granted, .create-granted").length,
      2,
      "everyone has full permissions"
    );

    assert.strictEqual(
      staffRow.querySelectorAll(".reply-granted, .create-granted").length,
      2,
      "staff group has full permissions (inherited from everyone)"
    );
  });
});
