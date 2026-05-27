import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import pretender from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

function latestCategorySavePayload() {
  const request = pretender.handledRequests.findLast(
    ({ method, requestBody }) => method === "PUT" && requestBody
  );

  return JSON.parse(request.requestBody);
}

acceptance("Category Edit", function (needs) {
  needs.user();
  needs.settings({ email_in: true, tagging_enabled: true });

  test("Editing the category", async function (assert) {
    await visit("/c/bug");

    await click("button.edit-category");
    assert.strictEqual(
      currentURL(),
      "/c/bug/edit/general",
      "jumps to the correct screen"
    );

    assert.dom(".category-breadcrumb .badge-category").hasText("bug");
    assert.dom(".badge-category__wrapper .badge-category").hasText("bug");
    await fillIn("input.category-name", "testing");
    assert
      .dom(".edit-category-tab-general .badge-category__name")
      .hasText("testing");

    await visit("/c/bug/edit/topic-template");
    await fillIn(".d-editor-input", "this is the new topic template");

    await click(".admin-changes-banner .btn-primary");
    assert.strictEqual(
      currentURL(),
      "/c/bug/edit/topic-template",
      "stays on the topic template screen"
    );

    await visit("/c/bug/edit/settings");
    await formKit().field("search_priority").select(1);

    await click(".admin-changes-banner .btn-primary");
    assert.strictEqual(
      currentURL(),
      "/c/bug/edit/settings",
      "stays on the settings screen"
    );

    sinon.stub(DiscourseURL, "routeTo");

    await click(".edit-category-security a");
    assert.true(
      DiscourseURL.routeTo.calledWith("/c/bug/edit/security"),
      "tab routing works"
    );
  });

  test("Editing required tag groups", async function (assert) {
    await visit("/c/bug/edit/tags");

    assert.dom("#category-minimum-tags").exists();

    assert.dom(".form-kit__collection").doesNotExist();

    await click(".add-required-tag-group");
    assert.dom(".form-kit__collection .form-kit__row").exists({ count: 1 });

    await click(".add-required-tag-group");
    assert.dom(".form-kit__collection .form-kit__row").exists({ count: 2 });

    await click(".delete-required-tag-group");
    assert.dom(".form-kit__collection .form-kit__row").exists({ count: 1 });

    const tagGroupChooser = selectKit(
      ".form-kit__collection .form-kit__row .tag-group-chooser"
    );
    await tagGroupChooser.expand();
    await tagGroupChooser.selectRowByValue("TagGroup1");

    await click(".admin-changes-banner .btn-primary");
    assert.dom(".form-kit__collection .form-kit__row").exists({ count: 1 });

    await click(".delete-required-tag-group");
    assert.dom(".form-kit__collection").doesNotExist();

    assert
      .dom(".admin-changes-banner")
      .exists("save banner stays visible when collection is emptied");
  });

  test("Editing allowed tags and tag groups", async function (assert) {
    await visit("/c/bug/edit/tags");

    await formKit().field("allowed_tags").selectByName("monkey");
    await formKit().control("#category-allowed-tag-groups").select("TagGroup1");

    await click(".admin-changes-banner .btn-primary");

    const payload = latestCategorySavePayload();
    assert.deepEqual(payload.allowed_tags, ["monkey"]);
    assert.deepEqual(payload.allowed_tag_groups, ["TagGroup1"]);

    await formKit().field("allowed_tags").deselectByName("monkey");
    await formKit()
      .control("#category-allowed-tag-groups")
      .deselectByValue("TagGroup1");

    await click(".admin-changes-banner .btn-primary");

    const removePayload = latestCategorySavePayload();
    assert.deepEqual(removePayload.allowed_tags, []);
    assert.deepEqual(removePayload.allowed_tag_groups, []);
  });

  test("Editing parent category (disabled Uncategorized)", async function (assert) {
    this.siteSettings.allow_uncategorized_topics = false;

    await visit("/c/bug/edit");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(6);

    await categoryChooser.expand();

    const names = [...categoryChooser.rows()].map((row) => row.dataset.name);
    assert.true(Boolean(categoryChooser.clearButton()));
    assert.false(names.includes("Uncategorized"));
  });

  test("Editing parent category (enabled Uncategorized)", async function (assert) {
    this.siteSettings.allow_uncategorized_topics = true;

    await visit("/c/bug/edit");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(6);

    await categoryChooser.expand();

    const names = [...categoryChooser.rows()].map((row) => row.dataset.name);
    assert.true(Boolean(categoryChooser.clearButton()));
    assert.false(names.includes("Uncategorized"));
  });

  test("Index Route", async function (assert) {
    await visit("/c/bug/edit");
    assert.strictEqual(
      currentURL(),
      "/c/bug/edit/general",
      "redirects to the general tab"
    );
  });

  test("Slugless Route", async function (assert) {
    await visit("/c/1-category/edit");
    assert.strictEqual(
      currentURL(),
      "/c/1-category/edit/general",
      "goes to the general tab"
    );
    assert.dom("input.category-name").hasValue("bug");
  });

  test("Error Saving", async function (assert) {
    await visit("/c/bug/edit/settings");

    // eslint-disable-next-line ember/require-valid-css-selector-in-test-helpers -- FormKit fillIn(value), not Ember fillIn(selector)
    await formKit().field("email_in").fillIn("duplicate@example.com");
    await click(".admin-changes-banner .btn-primary");

    assert.dom(".dialog-body").hasText(
      i18n("generic_error_with_reason", {
        error: "duplicate email",
      })
    );

    await click(".dialog-footer .btn-primary");
    assert.dom(".dialog-body").doesNotExist();
  });

  test("Nested subcategory error when saving", async function (assert) {
    this.siteSettings.max_category_nesting = 3;

    await visit("/c/bug/edit");

    const categoryChooser = selectKit(".category-chooser.single-select");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(1002);

    await click(".admin-changes-banner .btn-primary");

    assert.dom(".dialog-body").hasText(
      i18n("generic_error_with_reason", {
        error: "subcategory nested under another subcategory",
      })
    );

    await click(".dialog-footer .btn-primary");
    assert.dom(".dialog-body").doesNotExist();

    assert
      .dom(".category-breadcrumb .category-drop-header[data-value='1002']")
      .doesNotExist("doesn't show the nested subcategory in the breadcrumb");

    assert
      .dom(".category-breadcrumb .single-select-header[data-value='1002']")
      .doesNotExist("clears the category chooser");
  });

  test("Subcategory list settings", async function (assert) {
    await visit("/c/bug/edit/images");

    assert
      .dom("[data-name='subcategory_list_style']")
      .doesNotExist("subcategory list style isn't visible by default");

    await formKit().field("show_subcategory_list").toggle();

    assert
      .dom("[data-name='subcategory_list_style']")
      .exists(
        "subcategory list style is shown if show subcategory list is checked"
      );

    await visit("/c/bug/edit/general");

    const categoryChooser = selectKit(
      ".edit-category-tab-general .category-chooser"
    );
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(3);

    await visit("/c/bug/edit/images");

    assert
      .dom("[data-name='show_subcategory_list']")
      .doesNotExist("show subcategory list isn't visible for child categories");
    assert
      .dom("[data-name='subcategory_list_style']")
      .doesNotExist(
        "subcategory list style isn't visible for child categories"
      );
  });
});

acceptance(
  "Category Edit - parent category permission inheritance",
  function (needs) {
    needs.user();
    needs.pretender((server, helper) => {
      // Sub-category with only moderator permissions
      server.get("/c/restricted-group/find_by_slug.json", () =>
        helper.response(200, {
          category: {
            id: 2481,
            name: "restricted-group",
            color: "e9dd00",
            text_color: "000000",
            style_type: "square",
            slug: "restricted-group",
            read_restricted: true,
            can_edit: true,
            permission: 1,
            available_groups: ["admins", "moderators", "staff", "custom_group"],
            group_permissions: [
              { permission_type: 1, group_name: "moderators", group_id: 2 },
            ],
            custom_fields: {},
            category_types: {
              discussion: {
                id: "discussion",
                name: "Discussion",
                configuration_schema: {},
              },
            },
            available_category_types: [
              {
                id: "support",
                name: "Support",
                configuration_schema: {},
              },
            ],
          },
        })
      );

      // Parent with moderators + custom_group permissions
      server.get("/c/3/show.json", () =>
        helper.response(200, {
          category: {
            id: 3,
            name: "meta",
            color: "aaaaaa",
            text_color: "FFFFFF",
            slug: "meta",
            read_restricted: true,
            available_groups: ["admins", "staff"],
            group_permissions: [
              { permission_type: 1, group_name: "moderators", group_id: 2 },
              { permission_type: 1, group_name: "custom_group", group_id: 4 },
            ],
            category_types: {
              discussion: {
                id: "discussion",
                name: "Discussion",
                configuration_schema: {},
              },
            },
            available_category_types: [
              {
                id: "support",
                name: "Support",
                configuration_schema: {},
              },
            ],
          },
        })
      );

      // Parent with only custom_group permissions
      server.get("/c/6/show.json", () =>
        helper.response(200, {
          category: {
            id: 6,
            name: "support",
            color: "b99",
            text_color: "FFFFFF",
            slug: "support",
            read_restricted: true,
            available_groups: ["admins", "moderators", "staff"],
            group_permissions: [
              { permission_type: 1, group_name: "custom_group", group_id: 4 },
            ],
            category_types: {
              support: {
                id: "support",
                name: "Support",
                configuration_schema: {},
              },
            },
            available_category_types: [
              {
                id: "support",
                name: "Support",
                configuration_schema: {},
              },
            ],
          },
        })
      );

      // Public parent (everyone full permissions)
      server.get("/c/4/show.json", () =>
        helper.response(200, {
          category: {
            id: 4,
            name: "faq",
            color: "33b",
            text_color: "FFFFFF",
            slug: "faq",
            read_restricted: false,
            available_groups: ["admins", "moderators", "staff"],
            group_permissions: [
              { permission_type: 1, group_name: "everyone", group_id: 0 },
            ],
            category_types: {
              support: {
                id: "support",
                name: "Support",
                configuration_schema: {},
              },
            },
            available_category_types: [
              {
                id: "support",
                name: "Support",
                configuration_schema: {},
              },
            ],
          },
        })
      );

      // Sub-category with partial permissions (everyone: read, staff: full)
      server.get("/c/partial-group/find_by_slug.json", () =>
        helper.response(200, {
          category: {
            id: 2482,
            name: "partial-group",
            color: "e9dd00",
            text_color: "000000",
            style_type: "square",
            slug: "partial-group",
            read_restricted: false,
            can_edit: true,
            permission: 1,
            available_groups: ["admins", "moderators", "custom_group"],
            group_permissions: [
              { permission_type: 3, group_name: "everyone", group_id: 0 },
              { permission_type: 1, group_name: "staff", group_id: 3 },
            ],
            custom_fields: {},
            category_types: {
              discussion: {
                id: "discussion",
                name: "Discussion",
                configuration_schema: {},
              },
            },
            available_category_types: [
              {
                id: "support",
                name: "Support",
                configuration_schema: {},
              },
            ],
          },
        })
      );
    });

    test("retains sub-category permissions when sub is more restrictive than new parent", async function (assert) {
      await visit("/c/restricted-group/edit/general");

      const categoryChooser = selectKit(".category-chooser");
      await categoryChooser.expand();
      await categoryChooser.selectRowByValue(3);

      await click(".admin-changes-banner .btn-primary");

      const payload = latestCategorySavePayload();
      assert.deepEqual(payload.permissions, { moderators: 1 });
    });

    test("adopts parent permissions when parent is more restrictive than sub", async function (assert) {
      await visit("/c/restricted-group/edit/general");

      const categoryChooser = selectKit(".category-chooser");
      await categoryChooser.expand();
      await categoryChooser.selectRowByValue(6);

      await click(".admin-changes-banner .btn-primary");

      const payload = latestCategorySavePayload();
      assert.deepEqual(payload.permissions, { custom_group: 1 });
    });

    test("retains sub-category permissions when changing to a public parent", async function (assert) {
      await visit("/c/restricted-group/edit/general");

      const categoryChooser = selectKit(".category-chooser");
      await categoryChooser.expand();
      await categoryChooser.selectRowByValue(4);

      await click(".admin-changes-banner .btn-primary");

      const payload = latestCategorySavePayload();
      assert.deepEqual(payload.permissions, { moderators: 1 });
    });

    test("retains permissions when removing the parent from an existing sub-category", async function (assert) {
      await visit("/c/restricted-group/edit/general");

      const categoryChooser = selectKit(".category-chooser");
      await categoryChooser.expand();
      await categoryChooser.selectRowByValue(3);
      const clearButton = categoryChooser.clearButton();
      assert.true(Boolean(clearButton), "shows the clear button");
      await click(clearButton);

      await click(".admin-changes-banner .btn-primary");

      const payload = latestCategorySavePayload();
      assert.deepEqual(payload.permissions, { moderators: 1 });
    });

    test("retains partial permissions (everyone=readonly + staff=full) when changing to a fully public parent", async function (assert) {
      await visit("/c/partial-group/edit/general");

      const categoryChooser = selectKit(".category-chooser");
      await categoryChooser.expand();
      await categoryChooser.selectRowByValue(4);

      await click(".admin-changes-banner .btn-primary");

      const payload = latestCategorySavePayload();
      assert.deepEqual(payload.permissions, { everyone: 3, staff: 1 });
    });

    test("adopts private parent permissions when sub has partial public permissions", async function (assert) {
      await visit("/c/partial-group/edit/general");

      const categoryChooser = selectKit(".category-chooser");
      await categoryChooser.expand();
      await categoryChooser.selectRowByValue(6);

      await click(".admin-changes-banner .btn-primary");

      const payload = latestCategorySavePayload();
      assert.deepEqual(payload.permissions, { custom_group: 1 });
    });
  }
);

acceptance("Category Edit - no permission to edit", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/c/bug/find_by_slug.json", () => {
      return helper.response(200, {
        category: {
          id: 1,
          name: "bug",
          color: "e9dd00",
          text_color: "000000",
          slug: "bug",
          can_edit: false,
        },
      });
    });
  });

  test("returns 404", async function (assert) {
    await visit("/c/bug/edit");
    assert.strictEqual(currentURL(), "/404");
  });
});
