import { click, currentURL, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("Group Members - Anonymous", function () {
  test("Viewing Members as anon user", async function (assert) {
    await visit("/g/discourse");

    assert
      .dom(".avatar-flair .d-icon-circle-half-stroke")
      .exists("displays the group's avatar flair");
    assert.dom(".group-members .group-member").exists("lists group members");

    assert
      .dom(".group-member-dropdown")
      .doesNotExist("it does not allow anon user to manage group members");

    assert
      .dom(".group-username-filter")
      .hasAttribute(
        "placeholder",
        i18n("groups.members.filter_placeholder"),
        "it should display the right filter placeholder"
      );
  });
});

acceptance("Group Members", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.put("/groups/47/owners.json", () => {
      return helper.response({ success: true });
    });
  });

  test("Viewing Members as a group owner", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/g/discourse");
    await click(".group-members-add");

    assert.dom(".user-chooser").exists("displays the add members modal");
  });

  test("Viewing Members as an admin user", async function (assert) {
    await visit("/g/discourse");

    assert
      .dom(".group-member-dropdown")
      .exists("it allows admin user to manage group members");

    assert
      .dom(".group-username-filter")
      .hasAttribute(
        "placeholder",
        i18n("groups.members.filter_placeholder_admin"),
        "it should display the right filter placeholder"
      );
  });

  test("Shows bulk actions as an admin user", async function (assert) {
    await visit("/g/discourse");

    await click("button.bulk-select");

    await click(queryAll("input.bulk-select")[0]);
    await click(queryAll("input.bulk-select")[1]);

    const memberDropdown = selectKit(".bulk-group-member-dropdown");
    await memberDropdown.expand();

    assert
      .dom('[data-value="removeMembers"]')
      .exists("it includes remove member option");

    assert
      .dom('[data-value="makeOwners"]')
      .exists("it includes make owners option");

    assert
      .dom('[data-value="setPrimary"]')
      .exists("it includes set primary option");
  });

  test("Shows bulk actions as a group owner", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/g/discourse");

    await click("button.bulk-select");

    await click(queryAll("input.bulk-select")[0]);
    await click(queryAll("input.bulk-select")[1]);

    const memberDropdown = selectKit(".bulk-group-member-dropdown");
    await memberDropdown.expand();

    assert
      .dom('[data-value="removeMembers"]')
      .exists("it includes remove member option");

    assert
      .dom('[data-value="makeOwners"]')
      .exists("it includes make owners option");

    assert
      .dom('[data-value="setPrimary"]')
      .doesNotExist("it does not include set primary (staff only) option");
  });

  test("Bulk actions - Menu, Select all and Clear all buttons", async function (assert) {
    await visit("/g/discourse");

    assert
      .dom(".bulk-select-buttons-wrap details")
      .doesNotExist("it does not show menu button if nothing is selected");

    await click("button.bulk-select");
    await click(".bulk-select-all");

    assert
      .dom(".bulk-select-buttons-wrap details")
      .exists("it shows menu button if something is selected");
  });
});

/**
 * Workaround for https://github.com/tildeio/router.js/pull/335
 */
async function visitWithRedirects(url) {
  try {
    await visit(url);
  } catch (error) {
    const { message } = error;
    if (message !== "TransitionAborted") {
      throw error;
    }
    await settled();
  }
}

acceptance("Old group route redirections", function () {
  test("/group/discourse is redirected", async function (assert) {
    await visitWithRedirects("/group/discourse");
    assert.strictEqual(currentURL(), "/g/discourse");
  });

  test("/groups/discourse is redirected", async function (assert) {
    await visitWithRedirects("/groups/discourse");
    assert.strictEqual(currentURL(), "/g/discourse");
  });

  test("/groups is redirected", async function (assert) {
    await visitWithRedirects("/groups");
    assert.strictEqual(currentURL(), "/g");
  });
});
