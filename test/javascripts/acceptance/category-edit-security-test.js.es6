import { acceptance } from "helpers/qunit-helpers";

acceptance("Category Edit - security", {
  loggedIn: true
});

QUnit.test("default", async assert => {
  await visit("/c/bug");

  await click(".edit-category");
  await click("li.edit-category-security a");

  const $permissionListItems = find(".permission-list li");

  const badgeName = $permissionListItems
    .eq(0)
    .find(".badge-group")
    .text();
  assert.equal(badgeName, "everyone");

  const permission = $permissionListItems
    .eq(0)
    .find(".permission")
    .text();
  assert.equal(permission, "Create / Reply / See");
});

QUnit.test("removing a permission", async assert => {
  const availableGroups = selectKit(".available-groups");

  await visit("/c/bug");

  await click(".edit-category");
  await click("li.edit-category-security a");
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

QUnit.test("adding a permission", async assert => {
  const availableGroups = selectKit(".available-groups");
  const permissionSelector = selectKit(".permission-selector");

  await visit("/c/bug");

  await click(".edit-category");
  await click("li.edit-category-security a");
  await click(".edit-category-tab-security .edit-permission");
  await availableGroups.expand();
  await availableGroups.selectRowByValue("staff");
  await permissionSelector.expand();
  await permissionSelector.selectRowByValue("2");
  await click(".edit-category-tab-security .add-permission");

  const $addedPermissionItem = find(
    ".edit-category-tab-security .permission-list li:nth-child(2)"
  );

  const badgeName = $addedPermissionItem.find(".badge-group").text();
  assert.equal(badgeName, "staff");

  const permission = $addedPermissionItem.find(".permission").text();
  assert.equal(permission, "Reply / See");
});

QUnit.test("adding a previously removed permission", async assert => {
  const availableGroups = selectKit(".available-groups");

  await visit("/c/bug");

  await click(".edit-category");
  await await click("li.edit-category-security a");
  await click(".edit-category-tab-security .edit-permission");
  await click(
    ".edit-category-tab-security .permission-list li:first-of-type .remove-permission"
  );

  assert.equal(
    find(".edit-category-tab-security .permission-list li").length,
    0,
    "it removes the permission from the list"
  );

  await availableGroups.expand();
  await availableGroups.selectRowByValue("everyone");
  await click(".edit-category-tab-security .add-permission");

  assert.equal(
    find(".edit-category-tab-security .permission-list li").length,
    1,
    "it adds the permission to the list"
  );

  const $permissionListItems = find(".permission-list li");

  const badgeName = $permissionListItems
    .eq(0)
    .find(".badge-group")
    .text();
  assert.equal(badgeName, "everyone");

  const permission = $permissionListItems
    .eq(0)
    .find(".permission")
    .text();
  assert.equal(permission, "Create / Reply / See");
});
