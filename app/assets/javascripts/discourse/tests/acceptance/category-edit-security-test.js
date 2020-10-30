import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Category Edit - security", function (needs) {
  needs.user();

  test("default", async (assert) => {
    await visit("/c/bug/edit/security");

    const $firstItem = queryAll(".permission-list li:eq(0)");

    const badgeName = $firstItem.find(".badge-group").text();
    assert.equal(badgeName, "everyone");

    const permission = $firstItem.find(".permission").text();
    assert.equal(permission, "Create / Reply / See");
  });

  test("removing a permission", async (assert) => {
    const availableGroups = selectKit(".available-groups");

    await visit("/c/bug/edit/security");

    await click(".edit-category-tab-security .edit-permission");
    await availableGroups.expand();

    assert.notOk(
      availableGroups.rowByValue("everyone").exists(),
      "everyone is already used and is not in the available groups"
    );

    await click(
      ".edit-category-tab-security .permission-list li:first-of-type .remove-permission"
    );
    await availableGroups.expand();

    assert.ok(
      availableGroups.rowByValue("everyone").exists(),
      "everyone has been removed and appears in the available groups"
    );
  });

  test("adding a permission", async (assert) => {
    const availableGroups = selectKit(".available-groups");
    const permissionSelector = selectKit(".permission-selector");

    await visit("/c/bug/edit/security");

    await click(".edit-category-tab-security .edit-permission");
    await availableGroups.expand();
    await availableGroups.selectRowByValue("staff");
    await permissionSelector.expand();
    await permissionSelector.selectRowByValue("2");
    await click(".edit-category-tab-security .add-permission");

    const $addedPermissionItem = queryAll(
      ".edit-category-tab-security .permission-list li:nth-child(2)"
    );

    const badgeName = $addedPermissionItem.find(".badge-group").text();
    assert.equal(badgeName, "staff");

    const permission = $addedPermissionItem.find(".permission").text();
    assert.equal(permission, "Reply / See");
  });

  test("adding a previously removed permission", async (assert) => {
    const availableGroups = selectKit(".available-groups");

    await visit("/c/bug/edit/security");

    await click(".edit-category-tab-security .edit-permission");
    await click(
      ".edit-category-tab-security .permission-list li:first-of-type .remove-permission"
    );

    assert.equal(
      queryAll(".edit-category-tab-security .permission-list li").length,
      0,
      "it removes the permission from the list"
    );

    await availableGroups.expand();
    await availableGroups.selectRowByValue("everyone");
    await click(".edit-category-tab-security .add-permission");

    assert.equal(
      queryAll(".edit-category-tab-security .permission-list li").length,
      1,
      "it adds the permission to the list"
    );

    const $firstItem = queryAll(".permission-list li:eq(0)");

    const badgeName = $firstItem.find(".badge-group").text();
    assert.equal(badgeName, "everyone");

    const permission = $firstItem.find(".permission").text();
    assert.equal(permission, "Create / Reply / See");
  });
});
