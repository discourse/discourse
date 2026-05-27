import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AddCategoryTagClasses from "discourse/components/add-category-tag-classes";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | add-category-tag-classes", function (hooks) {
  setupRenderingTest(hooks);

  test("adds category classes to body", async function (assert) {
    const category = { fullSlug: "support" };

    await render(
      <template><AddCategoryTagClasses @category={{category}} /></template>
    );

    assert.dom(document.body).hasClass("category");
    assert.dom(document.body).hasClass("category-support");
  });

  test("adds tag classes when tags are objects", async function (assert) {
    const tags = [
      { id: 1, name: "bug", slug: "bug" },
      { id: 2, name: "feature", slug: "feature" },
    ];

    await render(<template><AddCategoryTagClasses @tags={{tags}} /></template>);

    assert.dom(document.body).hasClass("tag-bug");
    assert.dom(document.body).hasClass("tag-feature");
  });

  test("adds tag classes when tags are strings", async function (assert) {
    const tags = ["support", "help"];

    await render(<template><AddCategoryTagClasses @tags={{tags}} /></template>);

    assert.dom(document.body).hasClass("tag-support");
    assert.dom(document.body).hasClass("tag-help");
  });
});
