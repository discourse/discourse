import {
  acceptance,
  queryAll,
  visible,
} from "discourse/tests/helpers/qunit-helpers";
import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import DiscourseURL from "discourse/lib/url";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import sinon from "sinon";
import { test } from "qunit";

acceptance("Category Edit", function (needs) {
  needs.user();
  needs.settings({ email_in: true });

  test("Editing the category", async function (assert) {
    await visit("/c/bug");

    await click("button.edit-category");
    assert.equal(
      currentURL(),
      "/c/bug/edit/general",
      "it jumps to the correct screen"
    );

    assert.equal(
      queryAll(".category-breadcrumb .badge-category").text(),
      "bug"
    );
    assert.equal(
      queryAll(".category-color-editor .badge-category").text(),
      "bug"
    );
    await fillIn("input.category-name", "testing");
    assert.equal(
      queryAll(".category-color-editor .badge-category").text(),
      "testing"
    );

    await fillIn(".edit-text-color input", "ff0000");

    await click(".edit-category-topic-template");
    await fillIn(".d-editor-input", "this is the new topic template");

    await click("#save-category");
    assert.equal(
      currentURL(),
      "/c/bug/edit/general",
      "it stays on the edit screen"
    );

    await visit("/c/bug/edit/settings");
    const searchPriorityChooser = selectKit("#category-search-priority");
    await searchPriorityChooser.expand();
    await searchPriorityChooser.selectRowByValue(1);

    await click("#save-category");
    assert.equal(
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

  test("Index Route", async function (assert) {
    await visit("/c/bug/edit");
    assert.equal(
      currentURL(),
      "/c/bug/edit/general",
      "it redirects to the general tab"
    );
  });

  test("Slugless Route", async function (assert) {
    await visit("/c/1-category/edit");
    assert.equal(
      currentURL(),
      "/c/1-category/edit/general",
      "it goes to the general tab"
    );
    assert.equal(queryAll("input.category-name").val(), "bug");
  });

  test("Error Saving", async function (assert) {
    await visit("/c/bug/edit/settings");
    await fillIn(".email-in", "duplicate@example.com");
    await click("#save-category");

    assert.ok(visible(".bootbox"));
    assert.equal(queryAll(".bootbox .modal-body").html(), "duplicate email");

    await click(".bootbox .btn-primary");
    assert.ok(!visible(".bootbox"));
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
    assert.equal(currentURL(), "/404");
  });
});
