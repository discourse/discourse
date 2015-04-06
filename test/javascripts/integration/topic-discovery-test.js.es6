import { acceptance } from "helpers/qunit-helpers";
acceptance("Topic Discovery");

test("Visit Discovery Pages", () => {
  visit("/");
  andThen(() => {
    ok(exists(".topic-list"), "The list of topics was rendered");
    ok(exists('.topic-list .topic-list-item'), "has topics");
  });

  visit("/c/bug");
  andThen(() => {
    ok(exists(".topic-list"), "The list of topics was rendered");
    ok(exists('.topic-list .topic-list-item'), "has topics");
    ok($('body.category-bug').length, "has a custom css class for the category id on the body");
  });

  visit("/categories");
  andThen(() => {
    ok($('body.category-bug').length === 0, "removes the custom category class");

    ok(exists('.category'), "has a list of categories");
    ok($('body.categories-list').length, "has a custom class to indicate categories");
  });

  visit("/top");
  andThen(() => {
    ok($('body.categories-list').length === 0, "removes the `categories-list` class");
    ok(exists('.topic-list .topic-list-item'), "has topics");
  });
});
