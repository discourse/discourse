import { acceptance } from "helpers/qunit-helpers";

acceptance("Category Edit - security", {
  loggedIn: true
});

QUnit.test("default", assert => {
  visit("/c/bug");

  click(".edit-category");
  click("li.edit-category-security a");

  andThen(() => {
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
});

QUnit.test("removing a permission", assert => {
  const availableGroups = selectKit(".available-groups");

  visit("/c/bug");

  click(".edit-category");
  click("li.edit-category-security a");
  click(".edit-category-tab-security .edit-permission");
  availableGroups.expand();

  andThen(() => {
    assert.notOk(
      availableGroups.rowByValue("everyone").exists(),
      "everyone is already used and is not in the available groups"
    );
  });

  click(
    ".edit-category-tab-security .permission-list li:first-of-type .remove-permission"
  );
  availableGroups.expand();

  andThen(() => {
    assert.ok(
      availableGroups.rowByValue("everyone").exists(),
      "everyone has been removed and appears in the available groups"
    );
  });
});

QUnit.test("adding a permission", assert => {
  const availableGroups = selectKit(".available-groups");
  const permissionSelector = selectKit(".permission-selector");

  visit("/c/bug");

  click(".edit-category");
  click("li.edit-category-security a");
  click(".edit-category-tab-security .edit-permission");
  availableGroups.expand().selectRowByValue("staff");
  permissionSelector.expand().selectRowByValue("2");
  click(".edit-category-tab-security .add-permission");

  andThen(() => {
    const $addedPermissionItem = find(
      ".edit-category-tab-security .permission-list li:nth-child(2)"
    );

    const badgeName = $addedPermissionItem.find(".badge-group").text();
    assert.equal(badgeName, "staff");

    const permission = $addedPermissionItem.find(".permission").text();
    assert.equal(permission, "Reply / See");
  });
});

QUnit.test("adding a previously removed permission", assert => {
  const availableGroups = selectKit(".available-groups");

  visit("/c/bug");

  click(".edit-category");
  click("li.edit-category-security a");
  click(".edit-category-tab-security .edit-permission");
  click(
    ".edit-category-tab-security .permission-list li:first-of-type .remove-permission"
  );

  andThen(() => {
    assert.equal(
      find(".edit-category-tab-security .permission-list li").length,
      0,
      "it removes the permission from the list"
    );
  });

  availableGroups.expand().selectRowByValue("everyone");
  click(".edit-category-tab-security .add-permission");

  andThen(() => {
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
});
