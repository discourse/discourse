import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Category Edit - Security", function (needs) {
  needs.user();

  test("default", async function (assert) {
    await visit("/c/bug/edit/security");

    assert.dom(".row-body .group-name-label").hasText("everyone");
    assert.dom(".d-icon-square-check").exists({ count: 3 });
  });

  test("removing a permission", async function (assert) {
    await visit("/c/bug/edit/security");

    assert
      .dom(".available-groups option[value='0']")
      .doesNotExist(
        "everyone is already used and is not in the available groups"
      );

    await click(".row-body .remove-permission");

    assert
      .dom(".available-groups option[value='0']")
      .exists("everyone has been removed and appears in the available groups");
    assert
      .dom(".row-empty")
      .hasText(
        i18n("category.permissions.no_groups_selected"),
        "shows message when no groups are selected"
      );
  });

  test("adding a permission", async function (assert) {
    await visit("/c/bug/edit/security");

    await formKit().field("security_add_group_id").select("3");

    assert.dom("[data-group-name='staff'] .group-name-link").hasText("staff");
    assert
      .dom("[data-group-name='staff'] .d-icon-square-check")
      .exists(
        { count: 3 },
        "new row permissions match default 'everyone' permissions"
      );
  });

  test("adding a previously removed permission", async function (assert) {
    await visit("/c/bug/edit/security");
    await click(".row-body .remove-permission");

    assert
      .dom(".row-body")
      .doesNotExist("removes the permission from the list");

    await formKit().field("security_add_group_id").select("0");

    assert.dom(".row-body").exists("adds back the permission to the list");

    assert
      .dom(".row-body[data-group-name='everyone'] .group-name-label")
      .hasText("everyone");
    assert
      .dom(".row-body[data-group-name='everyone'] .d-icon-square-check")
      .exists({ count: 1 }, "adds only 'See' permission for a new row");
  });

  test("remove all permissions", async function (assert) {
    await visit("/c/bug/edit/security");

    assert
      .dom(".remove-all-permissions")
      .doesNotExist("button is hidden below the group threshold");

    await formKit().field("security_add_group_id").select("3");

    assert
      .dom(".remove-all-permissions")
      .doesNotExist("button is still hidden with two groups");

    await formKit().field("security_add_group_id").select("1");

    assert
      .dom(".remove-all-permissions")
      .exists("button appears once three or more groups are configured");

    await click(".remove-all-permissions");

    assert.dom(".row-body").doesNotExist("removes every group permission");
    assert
      .dom(".row-empty")
      .hasText(
        i18n("category.permissions.no_groups_selected"),
        "shows the empty message after removing all groups"
      );
  });

  test("editing permissions", async function (assert) {
    await visit("/c/bug/edit/security");

    assert
      .dom(
        "[data-group-name='everyone'] .reply-granted, [data-group-name='everyone'] .create-granted"
      )
      .exists({ count: 2 }, "everyone has full permissions by default");

    await formKit().field("security_add_group_id").select("3");

    assert
      .dom(
        "[data-group-name='staff'] .reply-granted, [data-group-name='staff'] .create-granted"
      )
      .exists({ count: 2 }, "staff group also has full permissions");

    await click("[data-group-name='everyone'] .reply-toggle");

    assert
      .dom(
        "[data-group-name='everyone'] .reply-granted, [data-group-name='everyone'] .create-granted"
      )
      .doesNotExist("everyone does not have reply or create");

    assert
      .dom(
        "[data-group-name='staff'] .reply-granted, [data-group-name='staff'] .create-granted"
      )
      .exists({ count: 2 }, "staff group still has full permissions");

    await click("[data-group-name='staff'] .reply-toggle");

    assert
      .dom(
        "[data-group-name='everyone'] .reply-granted, [data-group-name='everyone'] .create-granted"
      )
      .doesNotExist("everyone permission unchanged");

    assert
      .dom("[data-group-name='staff'] .reply-granted")
      .doesNotExist("staff does not have reply permission");

    assert
      .dom("[data-group-name='staff'] .create-granted")
      .doesNotExist("staff does not have create permission");

    await click("[data-group-name='everyone'] .create-toggle");

    assert
      .dom(
        "[data-group-name='everyone'] .reply-granted, [data-group-name='everyone'] .create-granted"
      )
      .exists({ count: 2 }, "everyone has full permissions");

    assert
      .dom(
        "[data-group-name='staff'] .reply-granted, [data-group-name='staff'] .create-granted"
      )
      .exists(
        { count: 2 },
        "staff group has full permissions (inherited from everyone)"
      );
  });
});
