import I18n from "I18n";
import {
  acceptance,
  count,
  exists,
  query,
  visible,
} from "discourse/tests/helpers/qunit-helpers";
import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import DiscourseURL from "discourse/lib/url";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import sinon from "sinon";
import { test } from "qunit";
import pretender from "discourse/tests/helpers/create-pretender";

acceptance("Category Edit", function (needs) {
  needs.user();
  needs.settings({ email_in: true, tagging_enabled: true });

  test("Editing the category", async function (assert) {
    await visit("/c/bug");

    await click("button.edit-category");
    assert.strictEqual(
      currentURL(),
      "/c/bug/edit/general",
      "it jumps to the correct screen"
    );

    assert.strictEqual(
      query(".category-breadcrumb .badge-category").innerText,
      "bug"
    );
    assert.strictEqual(
      query(".category-color-editor .badge-category").innerText,
      "bug"
    );
    await fillIn("input.category-name", "testing");
    assert.strictEqual(
      query(".category-color-editor .badge-category").innerText,
      "testing"
    );

    await fillIn(".edit-text-color input", "ff0000");

    await click(".edit-category-topic-template");
    await fillIn(".d-editor-input", "this is the new topic template");

    await click("#save-category");
    assert.strictEqual(
      currentURL(),
      "/c/bug/edit/general",
      "it stays on the edit screen"
    );

    await visit("/c/bug/edit/settings");
    const searchPriorityChooser = selectKit("#category-search-priority");
    await searchPriorityChooser.expand();
    await searchPriorityChooser.selectRowByValue(1);

    await click("#save-category");
    assert.strictEqual(
      currentURL(),
      "/c/bug/edit/settings",
      "it stays on the edit screen"
    );

    sinon.stub(DiscourseURL, "routeTo");

    await click(".edit-category-security a");
    assert.ok(
      DiscourseURL.routeTo.calledWith("/c/bug/edit/security"),
      "tab routing works"
    );
  });

  test("Editing required tag groups", async function (assert) {
    await visit("/c/bug/edit/tags");

    assert.ok(exists(".minimum-required-tags"));

    assert.ok(exists(".required-tag-groups"));
    assert.strictEqual(count(".required-tag-group-row"), 0);

    await click(".add-required-tag-group");
    assert.strictEqual(count(".required-tag-group-row"), 1);

    await click(".add-required-tag-group");
    assert.strictEqual(count(".required-tag-group-row"), 2);

    await click(".delete-required-tag-group");
    assert.strictEqual(count(".required-tag-group-row"), 1);

    const tagGroupChooser = selectKit(
      ".required-tag-group-row .tag-group-chooser"
    );
    await tagGroupChooser.expand();
    await tagGroupChooser.selectRowByValue("TagGroup1");

    await click("#save-category");
    assert.strictEqual(count(".required-tag-group-row"), 1);

    await click(".delete-required-tag-group");
    assert.strictEqual(count(".required-tag-group-row"), 0);

    await click("#save-category");
    assert.strictEqual(count(".required-tag-group-row"), 0);
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
    await allowedTagGroupChooser.collapse();

    await click("#save-category");

    const payload = JSON.parse(
      pretender.handledRequests[pretender.handledRequests.length - 1]
        .requestBody
    );
    assert.deepEqual(payload.allowed_tags, ["monkey"]);
    assert.deepEqual(payload.allowed_tag_groups, ["TagGroup1"]);

    await allowedTagChooser.expand();
    await allowedTagChooser.deselectItemByValue("monkey");
    await allowedTagChooser.collapse();

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

  test("Index Route", async function (assert) {
    await visit("/c/bug/edit");
    assert.strictEqual(
      currentURL(),
      "/c/bug/edit/general",
      "it redirects to the general tab"
    );
  });

  test("Slugless Route", async function (assert) {
    await visit("/c/1-category/edit");
    assert.strictEqual(
      currentURL(),
      "/c/1-category/edit/general",
      "it goes to the general tab"
    );
    assert.strictEqual(query("input.category-name").value, "bug");
  });

  test("Error Saving", async function (assert) {
    await visit("/c/bug/edit/settings");
    await fillIn(".email-in", "duplicate@example.com");
    await click("#save-category");

    assert.strictEqual(
      query(".dialog-body").textContent.trim(),
      I18n.t("generic_error_with_reason", {
        error: "duplicate email",
      })
    );

    await click(".dialog-footer .btn-primary");
    assert.ok(!visible(".dialog-body"));
  });

  test("Subcategory list settings", async function (assert) {
    await visit("/c/bug/edit/settings");

    assert.ok(
      !visible(".subcategory-list-style-field"),
      "subcategory list style isn't visible by default"
    );

    await click(".show-subcategory-list-field input[type=checkbox]");

    assert.ok(
      visible(".subcategory-list-style-field"),
      "subcategory list style is shown if show subcategory list is checked"
    );

    await visit("/c/bug/edit/general");

    const categoryChooser = selectKit(
      ".edit-category-tab-general .category-chooser"
    );
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(3);

    await visit("/c/bug/edit/settings");

    assert.ok(
      !visible(".show-subcategory-list-field"),
      "show subcategory list isn't visible for child categories"
    );
    assert.ok(
      !visible(".subcategory-list-style-field"),
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
