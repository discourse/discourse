import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("Category Edit - Security", function (needs) {
  needs.user();

  test("default", async function (assert) {
    await visit("/c/bug/edit/security");

    assert.dom(".row-body .group-name-label").hasText("everyone");
    assert.dom(".d-icon-square-check").exists({ count: 3 });
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

    assert.true(
      availableGroups.rowByValue("everyone").exists(),
      "everyone has been removed and appears in the available groups"
    );
    assert
      .dom(".row-empty")
      .hasText(
        i18n("category.permissions.no_groups_selected"),
        "shows message when no groups are selected"
      );
  });

  test("adding a permission", async function (assert) {
    const availableGroups = selectKit(".available-groups");

    await visit("/c/bug/edit/security");

    await availableGroups.expand();
    await availableGroups.selectRowByValue("staff");

    assert.dom("[data-group-name='staff'] .group-name-link").hasText("staff");
    assert
      .dom("[data-group-name='staff'] .d-icon-square-check")
      .exists(
        { count: 3 },
        "new row permissions match default 'everyone' permissions"
      );
  });

  test("adding a previously removed permission", async function (assert) {
    const availableGroups = selectKit(".available-groups");

    await visit("/c/bug/edit/security");
    await click(".row-body .remove-permission");

    assert
      .dom(".row-body")
      .doesNotExist("removes the permission from the list");

    await availableGroups.expand();
    await availableGroups.selectRowByValue("everyone");

    assert.dom(".row-body").exists("adds back the permission to the list");

    assert
      .dom(".row-body[data-group-name='everyone'] .group-name-label")
      .hasText("everyone");
    assert
      .dom(".row-body[data-group-name='everyone'] .d-icon-square-check")
      .exists({ count: 1 }, "adds only 'See' permission for a new row");
  });

  test("editing permissions", async function (assert) {
    const availableGroups = selectKit(".available-groups");

    await visit("/c/bug/edit/security");

    assert
      .dom(
        "[data-group-name='everyone'] .reply-granted, [data-group-name='everyone'] .create-granted"
      )
      .exists({ count: 2 }, "everyone has full permissions by default");

    await availableGroups.expand();
    await availableGroups.selectRowByValue("staff");

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
