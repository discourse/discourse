import {
  acceptance,
  exists,
  queryAll,
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

    assert.ok(queryAll(".badge-category"));
    assert.notOk(exists(".category-breadcrumb"));

    await fillIn("input.category-name", "testing");
    assert.equal(queryAll(".badge-category").text(), "testing");

    await click("#save-category");

    assert.equal(
      currentURL(),
      "/c/testing/edit/general",
      "it transitions to the category edit route"
    );

    assert.equal(
      queryAll(".edit-category-title h2").text(),
      I18n.t("category.edit_dialog_title", {
        categoryName: "testing",
      })
    );

    await click(".edit-category-security a");
    assert.ok(
      queryAll("button.edit-permission"),
      "it can switch to the security tab"
    );

    await click(".edit-category-settings a");
    assert.ok(
      queryAll("#category-search-priority"),
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
