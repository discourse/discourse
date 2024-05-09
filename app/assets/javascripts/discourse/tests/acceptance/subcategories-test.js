import { currentRouteName, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Subcategories", function () {
  test("navigation can be used to navigate subcategories pages", async function (assert) {
    await visit("/categories");

    let categoryDrop = selectKit(
      ".category-breadcrumb li:nth-of-type(1) .category-drop"
    );
    await categoryDrop.expand();
    await categoryDrop.selectRowByValue("2"); // "feature" category

    assert.strictEqual(currentRouteName(), "discovery.subcategories");
    assert.strictEqual(currentURL(), "/c/feature/2/subcategories");

    categoryDrop = selectKit(
      ".category-breadcrumb li:nth-of-type(2) .category-drop"
    );
    await categoryDrop.expand();
    await categoryDrop.selectRowByValue("26"); // "spec" category

    assert.strictEqual(currentRouteName(), "discovery.subcategories");
    assert.strictEqual(currentURL(), "/c/feature/spec/26/subcategories");
  });
});
