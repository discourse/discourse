import { acceptance } from "helpers/qunit-helpers";
acceptance("Topic Discovery");

QUnit.test("Visit Discovery Pages", assert => {
  visit("/");
  andThen(() => {
    assert.ok($("body.navigation-topics").length, "has the default navigation");
    assert.ok(exists(".topic-list"), "The list of topics was rendered");
    assert.ok(exists(".topic-list .topic-list-item"), "has topics");
  });

  visit("/c/bug");
  andThen(() => {
    assert.ok(exists(".topic-list"), "The list of topics was rendered");
    assert.ok(exists(".topic-list .topic-list-item"), "has topics");
    assert.ok(!exists(".category-list"), "doesn't render subcategories");
    assert.ok(
      $("body.category-bug").length,
      "has a custom css class for the category id on the body"
    );
  });

  visit("/categories");
  andThen(() => {
    assert.ok($("body.navigation-categories").length, "has the body class");
    assert.ok(
      $("body.category-bug").length === 0,
      "removes the custom category class"
    );
    assert.ok(exists(".category"), "has a list of categories");
    assert.ok(
      $("body.categories-list").length,
      "has a custom class to indicate categories"
    );
  });

  visit("/top");
  andThen(() => {
    assert.ok(
      $("body.categories-list").length === 0,
      "removes the `categories-list` class"
    );
    assert.ok(exists(".topic-list .topic-list-item"), "has topics");
  });

  visit("/c/feature");
  andThen(() => {
    assert.ok(exists(".topic-list"), "The list of topics was rendered");
    assert.ok(
      exists(".category-boxes"),
      "The list of subcategories were rendered with box style"
    );
  });

  visit("/c/dev");
  andThen(() => {
    assert.ok(exists(".topic-list"), "The list of topics was rendered");
    assert.ok(
      exists(".category-boxes-with-topics"),
      "The list of subcategories were rendered with box-with-featured-topics style"
    );
    assert.ok(
      exists(".category-boxes-with-topics .featured-topics"),
      "The featured topics are there too"
    );
  });
});
