import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import Site from "discourse/models/site";
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

acceptance("Category Edit - Logged-in permissions", function (needs) {
  let parentCategoryId;
  needs.hooks.beforeEach(() => {
    parentCategoryId = null;
  });
  needs.user();
  needs.settings({ granular_anonymous_and_logged_in_groups_permissions: true });
  needs.site({
    groups: [
      { id: 4, name: "anonymous_users", automatic: true },
      { id: 5, name: "logged_in_users", automatic: true },
      { id: 42, name: "custom_group" },
    ],
  });
  needs.pretender((server, helper) => {
    server.get("/c/bug/find_by_slug.json", () =>
      helper.response({
        category: {
          id: 1,
          name: "bug",
          slug: "bug",
          parent_category_id: parentCategoryId,
          can_edit: true,
          available_groups: ["everyone", "logged_in_users", "custom_group"],
          permission_groups: [
            { id: 0, name: "everyone" },
            { id: 5, name: "logged_in_users" },
            { id: 42, name: "custom_group" },
          ],
          group_permissions: [
            { group_id: 5, group_name: "logged_in_users", permission_type: 3 },
          ],
        },
      })
    );
  });

  test("category choices retain everyone and exclude anonymous users", async function (assert) {
    await visit("/c/bug/edit/security");

    assert
      .dom(".available-groups option[value='0']")
      .exists(
        "public access remains available when the UC hides everyone globally"
      );
    assert
      .dom(".available-groups option[value='4']")
      .doesNotExist("anonymous grants are unavailable for categories");
    assert
      .dom("[data-group-name='logged_in_users']")
      .exists("the saved logged-in grant remains visible");

    await formKit().field("security_add_group_id").select("0");

    assert
      .dom("[data-group-name='everyone']")
      .exists("adding public access uses the category-specific group name");
  });
  test("a logged-in parent permits custom-group children but excludes public access", async function (assert) {
    parentCategoryId = 99;
    Site.current().updateCategory({
      id: parentCategoryId,
      name: "Logged-in parent",
      slug: "logged-in-parent",
      available_groups: ["logged_in_users"],
      group_permissions: [
        { group_id: 5, group_name: "logged_in_users", permission_type: 3 },
      ],
    });

    await visit("/c/bug/edit/security");

    assert
      .dom(".available-groups option[value='42']")
      .exists("custom group members can access the logged-in parent");
    assert
      .dom(".available-groups option[value='0']")
      .doesNotExist(
        "a public child would expose content beyond the parent audience"
      );
  });
});
