import createStore from "helpers/create-store";

QUnit.module("lib:category-link");

import { categoryBadgeHTML } from "discourse/helpers/category-link";

QUnit.test("categoryBadge without a category", assert => {
  assert.blank(categoryBadgeHTML(), "it returns no HTML");
});

QUnit.test("Regular categoryBadge", assert => {
  const store = createStore();
  const category = store.createRecord("category", {
    name: "hello",
    id: 123,
    description_text: "cool description",
    color: "ff0",
    text_color: "f00"
  });
  const tag = $.parseHTML(categoryBadgeHTML(category))[0];

  assert.equal(tag.tagName, "A", "it creates a `a` wrapper tag");
  assert.equal(
    tag.className.trim(),
    "badge-wrapper",
    "it has the correct class"
  );

  const label = tag.children[1];
  assert.equal(label.title, "cool description", "it has the correct title");
  assert.equal(
    label.children[0].innerText,
    "hello",
    "it has the category name"
  );
});

QUnit.test("undefined color", assert => {
  const store = createStore();
  const noColor = store.createRecord("category", { name: "hello", id: 123 });
  const tag = $.parseHTML(categoryBadgeHTML(noColor))[0];

  assert.blank(
    tag.attributes["style"],
    "it has no color style because there are no colors"
  );
});

QUnit.test("allowUncategorized", assert => {
  const store = createStore();
  const uncategorized = store.createRecord("category", {
    name: "uncategorized",
    id: 345
  });
  sandbox
    .stub(Discourse.Site, "currentProp")
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

QUnit.test("category names are wrapped in dir-spans", assert => {
  Discourse.SiteSettings.support_mixed_text_direction = true;
  const store = createStore();
  const rtlCategory = store.createRecord("category", {
    name: "תכנות עם Ruby",
    id: 123,
    description_text: "cool description",
    color: "ff0",
    text_color: "f00"
  });

  const ltrCategory = store.createRecord("category", {
    name: "Programming in Ruby",
    id: 234
  });

  let tag = $.parseHTML(categoryBadgeHTML(rtlCategory))[0];
  let dirSpan = tag.children[1].children[0];
  assert.equal(dirSpan.dir, "rtl");

  tag = $.parseHTML(categoryBadgeHTML(ltrCategory))[0];
  dirSpan = tag.children[1].children[0];
  assert.equal(dirSpan.dir, "ltr");
});

QUnit.test("recursive", assert => {
  const store = createStore();

  const foo = store.createRecord("category", {
    name: "foo",
    id: 1
  });

  const bar = store.createRecord("category", {
    name: "bar",
    id: 2,
    parent_category_id: foo.id
  });

  const baz = store.createRecord("category", {
    name: "baz",
    id: 3,
    parent_category_id: bar.id
  });

  Discourse.set("SiteSettings.max_category_nesting", 0);
  assert.ok(categoryBadgeHTML(baz, { recursive: true }).indexOf("baz") !== -1);
  assert.ok(categoryBadgeHTML(baz, { recursive: true }).indexOf("bar") === -1);

  Discourse.set("SiteSettings.max_category_nesting", 1);
  assert.ok(categoryBadgeHTML(baz, { recursive: true }).indexOf("baz") !== -1);
  assert.ok(categoryBadgeHTML(baz, { recursive: true }).indexOf("bar") === -1);

  Discourse.set("SiteSettings.max_category_nesting", 2);
  assert.ok(categoryBadgeHTML(baz, { recursive: true }).indexOf("baz") !== -1);
  assert.ok(categoryBadgeHTML(baz, { recursive: true }).indexOf("bar") !== -1);
  assert.ok(categoryBadgeHTML(baz, { recursive: true }).indexOf("foo") === -1);

  Discourse.set("SiteSettings.max_category_nesting", 3);
  assert.ok(categoryBadgeHTML(baz, { recursive: true }).indexOf("baz") !== -1);
  assert.ok(categoryBadgeHTML(baz, { recursive: true }).indexOf("bar") !== -1);
  assert.ok(categoryBadgeHTML(baz, { recursive: true }).indexOf("foo") !== -1);
});
