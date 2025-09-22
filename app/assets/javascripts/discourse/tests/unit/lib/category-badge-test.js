import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import $ from "jquery";
import { module, test } from "qunit";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import { helperContext } from "discourse/lib/helpers";

module("Unit | Utility | category-badge", function (hooks) {
  setupTest(hooks);

  test("categoryBadge without a category", function (assert) {
    assert.blank(categoryBadgeHTML(), "returns no HTML");
  });

  test("regular categoryBadge", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const category = store.createRecord("category", {
      name: "hello",
      id: 123,
      description_text: "cool description",
      color: "ff0",
      text_color: "f00",
    });
    const tag = $.parseHTML(categoryBadgeHTML(category))[0];

    assert.strictEqual(tag.tagName, "A", "creates a `a` wrapper tag");
    assert.strictEqual(
      tag.className.trim(),
      "badge-category__wrapper",
      "has the correct class"
    );

    const label = tag.children[0];
    assert
      .dom(label)
      .hasAttribute("title", "cool description", "has the correct title");
    assert.dom(label.children[0]).hasText("hello", "has the category name");
  });

  test("undefined color", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const noColor = store.createRecord("category", { name: "hello", id: 123 });
    const tag = $.parseHTML(categoryBadgeHTML(noColor))[0];

    assert.blank(
      tag.attributes["style"],
      "has no color style because there are no colors"
    );
  });

  test("topic count", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const category = store.createRecord("category", { name: "hello", id: 123 });

    assert.false(
      categoryBadgeHTML(category).includes("topic-count"),
      "does not include topic count by default"
    );
    assert.true(
      categoryBadgeHTML(category, { topicCount: 20 }).indexOf("topic-count") >
        20,
      "is included when specified"
    );
  });

  test("allowUncategorized", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const uncategorized = store.createRecord("category", {
      name: "uncategorized",
      id: 345,
    });

    const { site } = helperContext();
    site.set("uncategorized_category_id", 345);

    assert.blank(
      categoryBadgeHTML(uncategorized),
      "doesn't return HTML for uncategorized by default"
    );
    assert.present(
      categoryBadgeHTML(uncategorized, { allowUncategorized: true }),
      "returns HTML"
    );
  });

  test("category names are wrapped in dir-spans", function (assert) {
    const siteSettings = getOwner(this).lookup("service:site-settings");
    siteSettings.support_mixed_text_direction = true;

    const store = getOwner(this).lookup("service:store");
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

    let dirSpan = tag.children[0].children[0];
    assert.strictEqual(dirSpan.dir, "auto");

    tag = $.parseHTML(categoryBadgeHTML(ltrCategory))[0];
    dirSpan = tag.children[0].children[0];
    assert.strictEqual(dirSpan.dir, "auto");
  });

  test("recursive", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const siteSettings = getOwner(this).lookup("service:site-settings");

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

    siteSettings.max_category_nesting = 0;
    assert.true(categoryBadgeHTML(baz, { recursive: true }).includes("baz"));
    assert.false(categoryBadgeHTML(baz, { recursive: true }).includes("bar"));

    siteSettings.max_category_nesting = 1;
    assert.true(categoryBadgeHTML(baz, { recursive: true }).includes("baz"));
    assert.false(categoryBadgeHTML(baz, { recursive: true }).includes("bar"));

    siteSettings.max_category_nesting = 2;
    assert.true(categoryBadgeHTML(baz, { recursive: true }).includes("baz"));
    assert.true(categoryBadgeHTML(baz, { recursive: true }).includes("bar"));
    assert.false(categoryBadgeHTML(baz, { recursive: true }).includes("foo"));

    siteSettings.max_category_nesting = 3;
    assert.true(categoryBadgeHTML(baz, { recursive: true }).includes("baz"));
    assert.true(categoryBadgeHTML(baz, { recursive: true }).includes("bar"));
    assert.true(categoryBadgeHTML(baz, { recursive: true }).includes("foo"));
  });

  test("category style types", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const category = store.createRecord("category", { name: "hello", id: 123 });

    assert.true(
      categoryBadgeHTML(category).includes("--style-square"),
      "has square style by default"
    );

    assert.true(
      categoryBadgeHTML(category, {
        styleType: "icon",
        icon: "book",
      }).includes("--style-icon"),
      "has icon style"
    );

    assert.true(
      categoryBadgeHTML(category, {
        styleType: "emoji",
        emoji: "wave",
      }).includes("--style-emoji"),
      "has emoji style"
    );
  });

  test("category style with ancestors", function (assert) {
    const store = getOwner(this).lookup("service:store");

    const emojiParent = store.createRecord("category", {
      name: "hello",
      id: 123,
      style_type: "icon",
      icon: "book",
    });
    const emojiChild = store.createRecord("category", {
      name: "world",
      id: 456,
      style_type: "icon",
      icon: "file",
      parent_category_id: emojiParent.id,
    });

    const badge = categoryBadgeHTML(emojiChild, { ancestors: [emojiParent] });

    assert.true(badge.includes("d-icon-book"), "has parent with book icon");
    assert.true(badge.includes("d-icon-file"), "has child with file icon");
  });
});
