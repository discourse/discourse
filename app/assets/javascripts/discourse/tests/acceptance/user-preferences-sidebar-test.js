import { test } from "qunit";

import { click, visit } from "@ember/test-helpers";

import {
  acceptance,
  exists,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("User Preferences - Sidebar", function (needs) {
  needs.user({
    sidebar_category_ids: [],
    sidebar_tags: [],
  });

  needs.settings({
    enable_experimental_sidebar_hamburger: true,
    enable_sidebar: true,
    tagging_enabled: true,
  });

  let updateUserRequestBody = null;

  needs.hooks.afterEach(() => {
    updateUserRequestBody = null;
  });

  needs.pretender((server, helper) => {
    server.put("/u/eviltrout.json", (request) => {
      updateUserRequestBody = helper.parsePostData(request.requestBody);

      // if only the howto category is updated, intentionally cause an error
      if (
        updateUserRequestBody["sidebar_category_ids[]"]?.[0] === "10" ||
        updateUserRequestBody["sidebar_tag_names[]"]?.[0] === "gazelle"
      ) {
        // This request format will cause an error
        return helper.response(400, {});
      } else {
        return helper.response({
          user: {
            sidebar_tags: [
              { name: "monkey", pm_only: false },
              { name: "gazelle", pm_only: false },
            ],
          },
        });
      }
    });
  });

  test("user should not see tag chooser when tagging is disabled", async function (assert) {
    this.siteSettings.tagging_enabled = false;

    await visit("/u/eviltrout/preferences/sidebar");

    assert.ok(!exists(".tag-chooser"), "tag chooser is not displayed");
  });

  test("user encountering error when adding categories to sidebar", async function (assert) {
    updateCurrentUser({ sidebar_category_ids: [6] });

    await visit("/");

    assert.ok(
      exists(".sidebar-section-categories .sidebar-section-link-support"),
      "support category is present in sidebar"
    );

    await click(".sidebar-section-categories .sidebar-section-header-button");

    const categorySelector = selectKit(".category-selector");
    await categorySelector.expand();
    await categorySelector.selectKitSelectRowByName("howto");
    await categorySelector.deselectItemByName("support");

    await click(".save-changes");

    assert.deepEqual(
      updateUserRequestBody["sidebar_category_ids[]"],
      ["10"],
      "contains the right request body to update user's sidebar category links"
    );

    assert.ok(exists(".modal-body"), "error message is displayed");

    await click(".modal .d-button-label");

    assert.ok(
      !exists(".sidebar-section-categories .sidebar-section-link-howto"),
      "howto category is not displayed in sidebar"
    );

    assert.ok(
      exists(".sidebar-section-categories .sidebar-section-link-support"),
      "support category is displayed in sidebar"
    );
  });

  test("user adding categories to sidebar", async function (assert) {
    await visit("/");
    await click(".sidebar-section-categories .sidebar-section-header-button");

    const categorySelector = selectKit(".category-selector");
    await categorySelector.expand();
    await categorySelector.selectKitSelectRowByName("support");
    await categorySelector.selectKitSelectRowByName("bug");

    await click(".save-changes");

    assert.ok(
      exists(".sidebar-section-categories .sidebar-section-link-support"),
      "support category has been added to sidebar"
    );

    assert.ok(
      exists(".sidebar-section-categories .sidebar-section-link-bug"),
      "bug category has been added to sidebar"
    );

    assert.deepEqual(
      updateUserRequestBody["sidebar_category_ids[]"],
      ["6", "1"],
      "contains the right request body to update user's sidebar category links"
    );
  });

  test("user encountering error when adding tags to sidebar", async function (assert) {
    updateCurrentUser({ sidebar_tags: [{ name: "monkey", pm_only: false }] });

    await visit("/");

    assert.ok(
      exists(".sidebar-section-tags .sidebar-section-link-monkey"),
      "monkey tag is displayed in sidebar"
    );

    await click(".sidebar-section-tags .sidebar-section-header-button");

    const tagChooser = selectKit(".tag-chooser");
    await tagChooser.expand();
    await tagChooser.selectKitSelectRowByName("gazelle");
    await tagChooser.deselectItemByName("monkey");

    await click(".save-changes");

    assert.deepEqual(
      updateUserRequestBody["sidebar_tag_names[]"],
      ["gazelle"],
      "contains the right request body to update user's sidebar tag links"
    );

    assert.ok(exists(".modal-body"), "error message is displayed");

    await click(".modal .d-button-label");

    assert.ok(
      !exists(".sidebar-section-tags .sidebar-section-link-gazelle"),
      "gazelle tag is not displayed in sidebar"
    );

    assert.ok(
      exists(".sidebar-section-tags .sidebar-section-link-monkey"),
      "monkey tag is displayed in sidebar"
    );
  });

  test("user adding tags to sidebar", async function (assert) {
    await visit("/");
    await click(".sidebar-section-tags .sidebar-section-header-button");

    const tagChooser = selectKit(".tag-chooser");
    await tagChooser.expand();
    await tagChooser.selectKitSelectRowByName("monkey");
    await tagChooser.selectKitSelectRowByName("gazelle");

    await click(".save-changes");

    assert.ok(
      exists(".sidebar-section-tags .sidebar-section-link-monkey"),
      "monkey tag has been added to sidebar"
    );

    assert.ok(
      exists(".sidebar-section-tags .sidebar-section-link-gazelle"),
      "gazelle tag has been added to sidebar"
    );

    assert.deepEqual(
      updateUserRequestBody["sidebar_tag_names[]"],
      ["monkey", "gazelle"],
      "contains the right request body to update user's sidebar tag links"
    );
  });
});
