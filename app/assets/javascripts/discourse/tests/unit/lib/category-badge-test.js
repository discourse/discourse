import Site from "discourse/models/site";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import createStore from "discourse/tests/helpers/create-store";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import sinon from "sinon";
import { test } from "qunit";

discourseModule("Unit | Utility | category-badge", function () {
  test("categoryBadge without a category", function (assert) {
    assert.blank(categoryBadgeHTML(), "it returns no HTML");
  });

  test("Regular categoryBadge", function (assert) {
    const store = createStore();
    const category = store.createRecord("category", {
      name: "hello",
      id: 123,
      description_text: "cool description",
      color: "ff0",
      text_color: "f00",
    });
    const tag = $.parseHTML(categoryBadgeHTML(category))[0];

    assert.strictEqual(tag.tagName, "A", "it creates a `a` wrapper tag");
    assert.strictEqual(
      tag.className.trim(),
      "badge-wrapper bullet",
      "it has the correct class"
    );

    const label = tag.children[1];
    assert.strictEqual(
      label.title,
      "cool description",
      "it has the correct title"
    );
    assert.strictEqual(
      label.children[0].innerText,
      "hello",
      "it has the category name"
    );
  });

  test("undefined color", function (assert) {
    const store = createStore();
    const noColor = store.createRecord("category", { name: "hello", id: 123 });
    const tag = $.parseHTML(categoryBadgeHTML(noColor))[0];

    assert.blank(
      tag.attributes["style"],
      "it has no color style because there are no colors"
    );
  });

  test("topic count", function (assert) {
    const store = createStore();
    const category = store.createRecord("category", { name: "hello", id: 123 });

    assert.ok(
      !categoryBadgeHTML(category).includes("topic-count"),
      "it does not include topic count by default"
    );
    assert.ok(
      categoryBadgeHTML(category, { topicCount: 20 }).indexOf("topic-count") >
        20,
      "is included when specified"
    );
  });

  test("allowUncategorized", function (assert) {
    const store = createStore();
    const uncategorized = store.createRecord("category", {
      name: "uncategorized",
      id: 345,
    });

    sinon
      .stub(Site, "currentProp")
      .withArgs("uncategorized_category_id")
      .returns(345);

    assert.blank(
      categoryBadgeHTML(uncategorized),
      "it doesn't return HTML for uncategorized by default"
    );
    assert.present(
      categoryBadgeHTML(uncategorized, { allowUncategorized: true }),
      "it returns HTML"
    );
  });

  test("category names are wrapped in dir-spans", function (assert) {
    this.siteSettings.support_mixed_text_direction = true;
    const store = createStore();
    const rtlCategory = store.createRecord("category", {
      name: "תכנות עם Ruby",
      id: 123,
      description_text: "cool description",
      color: "ff0",
      text_color: "f00",
    });

    const ltrCategory = store.createRecord("category", {
      name: "Programming in Ruby",
      id: 234,
    });

    let tag = $.parseHTML(categoryBadgeHTML(rtlCategory))[0];
    let dirSpan = tag.children[1].children[0];
    assert.strictEqual(dirSpan.dir, "rtl");

    tag = $.parseHTML(categoryBadgeHTML(ltrCategory))[0];
    dirSpan = tag.children[1].children[0];
    assert.strictEqual(dirSpan.dir, "ltr");
  });

  test("recursive", function (assert) {
    const store = createStore();

    const foo = store.createRecord("category", {
      name: "foo",
      id: 1,
    });

    const bar = store.createRecord("category", {
      name: "bar",
      id: 2,
      parent_category_id: foo.id,
    });

    const baz = store.createRecord("category", {
      name: "baz",
      id: 3,
      parent_category_id: bar.id,
    });

    this.siteSettings.max_category_nesting = 0;
    assert.ok(categoryBadgeHTML(baz, { recursive: true }).includes("baz"));
    assert.ok(!categoryBadgeHTML(baz, { recursive: true }).includes("bar"));

    this.siteSettings.max_category_nesting = 1;
    assert.ok(categoryBadgeHTML(baz, { recursive: true }).includes("baz"));
    assert.ok(!categoryBadgeHTML(baz, { recursive: true }).includes("bar"));

    this.siteSettings.max_category_nesting = 2;
    assert.ok(categoryBadgeHTML(baz, { recursive: true }).includes("baz"));
    assert.ok(categoryBadgeHTML(baz, { recursive: true }).includes("bar"));
    assert.ok(!categoryBadgeHTML(baz, { recursive: true }).includes("foo"));

    this.siteSettings.max_category_nesting = 3;
    assert.ok(categoryBadgeHTML(baz, { recursive: true }).includes("baz"));
    assert.ok(categoryBadgeHTML(baz, { recursive: true }).includes("bar"));
    assert.ok(categoryBadgeHTML(baz, { recursive: true }).includes("foo"));
  });
});
