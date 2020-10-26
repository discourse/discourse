import { fillIn, click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import DiscourseURL from "discourse/lib/url";

acceptance("Category New", function (needs) {
  needs.user();

  test("Creating a new category", async (assert) => {
    await visit("/new-category");
    assert.ok(find(".badge-category"));

    await fillIn("input.category-name", "testing");
    assert.equal(find(".badge-category").text(), "testing");

    await click("#save-category");

    assert.equal(
      find(".edit-category-title h2").text(),
      I18n.t("category.edit_dialog_title", {
        categoryName: "testing",
      })
    );

    await click(".category-back");

    assert.equal(
      DiscourseURL.redirectedTo,
      "/c/testing/11",
      "it full page redirects after a newly created category"
    );
  });
});
