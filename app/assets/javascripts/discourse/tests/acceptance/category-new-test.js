import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import sinon from "sinon";
import { test } from "qunit";

acceptance("Category New", function (needs) {
  needs.user();

  test("Creating a new category", async function (assert) {
    await visit("/new-category");

    assert.ok(exists(".badge-category"));
    assert.notOk(exists(".category-breadcrumb"));

    await fillIn("input.category-name", "testing");
    assert.strictEqual(query(".badge-category").innerText, "testing");

    await click("#save-category");

    assert.strictEqual(
      currentURL(),
      "/c/testing/edit/general",
      "it transitions to the category edit route"
    );

    assert.strictEqual(
      query(".edit-category-title h2").innerText,
      I18n.t("category.edit_dialog_title", {
        categoryName: "testing",
      })
    );

    await click(".edit-category-security a");
    assert.ok(
      exists(".permission-row button.reply-toggle"),
      "it can switch to the security tab"
    );

    await click(".edit-category-settings a");
    assert.ok(
      exists("#category-search-priority"),
      "it can switch to the settings tab"
    );

    sinon.stub(DiscourseURL, "routeTo");

    await click(".category-back");
    assert.ok(
      DiscourseURL.routeTo.calledWith("/c/testing/11"),
      "back routing works"
    );
  });
});
