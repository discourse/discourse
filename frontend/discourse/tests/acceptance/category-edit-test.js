import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import pretender from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

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
    assert.dom(".category-style .badge-category__name").hasText("testing");

    await click(".edit-category-topic-template a");
    await fillIn(".d-editor-input", "this is the new topic template");

    await click("#save-category");
    assert.strictEqual(
      currentURL(),
      "/c/bug/edit/topic-template",
      "stays on the topic template screen"
    );

    await visit("/c/bug/edit/settings");
    const searchPriorityChooser = selectKit("#category-search-priority");
    await searchPriorityChooser.expand();
    await searchPriorityChooser.selectRowByValue(1);

    await click("#save-category");
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

    assert.dom(".minimum-required-tags").exists();

    assert.dom(".required-tag-groups").exists();
    assert.dom(".required-tag-group-row").doesNotExist();

    await click(".add-required-tag-group");
    assert.dom(".required-tag-group-row").exists({ count: 1 });

    await click(".add-required-tag-group");
    assert.dom(".required-tag-group-row").exists({ count: 2 });

    await click(".delete-required-tag-group");
    assert.dom(".required-tag-group-row").exists({ count: 1 });

    const tagGroupChooser = selectKit(
      ".required-tag-group-row .tag-group-chooser"
    );
    await tagGroupChooser.expand();
    await tagGroupChooser.selectRowByValue("TagGroup1");

    await click("#save-category");
    assert.dom(".required-tag-group-row").exists({ count: 1 });

    await click(".delete-required-tag-group");
    assert.dom(".required-tag-group-row").doesNotExist();

    await click("#save-category");
    assert.dom(".required-tag-group-row").doesNotExist();
  });

  test("Editing allowed tags and tag groups", async function (assert) {
    await visit("/c/bug/edit/tags");

    const allowedTagChooser = selectKit("#category-allowed-tags");
    await allowedTagChooser.expand();
    await allowedTagChooser.selectRowByValue("monkey");

    await allowedTagChooser.collapse();
    const allowedTagGroupChooser = selectKit("#category-allowed-tag-groups");
    await allowedTagGroupChooser.expand();
    await allowedTagGroupChooser.selectRowByValue("TagGroup1");

    await click("#save-category");

    const payload = JSON.parse(
      pretender.handledRequests[pretender.handledRequests.length - 1]
        .requestBody
    );
    assert.deepEqual(payload.allowed_tags, ["monkey"]);
    assert.deepEqual(payload.allowed_tag_groups, ["TagGroup1"]);

    await allowedTagGroupChooser.collapse();
    await allowedTagChooser.expand();
    await allowedTagChooser.deselectItemByValue("monkey");

    await allowedTagGroupChooser.expand();
    await allowedTagGroupChooser.deselectItemByValue("TagGroup1");

    await click("#save-category");

    const removePayload = JSON.parse(
      pretender.handledRequests[pretender.handledRequests.length - 1]
        .requestBody
    );
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
    assert.true(names.includes("(no category)"));
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
    assert.true(names.includes("(no category)"));
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
    await fillIn(".email-in", "duplicate@example.com");
    await click("#save-category");

    assert.dom(".dialog-body").hasText(
      i18n("generic_error_with_reason", {
        error: "duplicate email",
      })
    );

    await click(".dialog-footer .btn-primary");
    assert.dom(".dialog-body").doesNotExist();
  });

  test("Nested subcategory error when saving", async function (assert) {
    await visit("/c/bug/edit");

    const categoryChooser = selectKit(".category-chooser.single-select");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(1002);

    await click("#save-category");

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
    await visit("/c/bug/edit/settings");

    assert
      .dom(".subcategory-list-style-field")
      .doesNotExist("subcategory list style isn't visible by default");

    await click(".show-subcategory-list-field input[type=checkbox]");

    assert
      .dom(".subcategory-list-style-field")
      .exists(
        "subcategory list style is shown if show subcategory list is checked"
      );

    await visit("/c/bug/edit/general");

    const categoryChooser = selectKit(
      ".edit-category-tab-general .category-chooser"
    );
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(3);

    await visit("/c/bug/edit/settings");

    assert
      .dom(".show-subcategory-list-field")
      .doesNotExist("show subcategory list isn't visible for child categories");
    assert
      .dom(".subcategory-list-style-field")
      .doesNotExist(
        "subcategory list style isn't visible for child categories"
      );
  });
});

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
