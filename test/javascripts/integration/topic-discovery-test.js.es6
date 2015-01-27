integration("Topic Discovery");

test("Visit Discovery Pages", function() {
  visit("/");
  andThen(function() {
    ok(exists(".topic-list"), "The list of topics was rendered");
    ok(exists('.topic-list .topic-list-item'), "has topics");
  });

  visit("/c/bug");
  andThen(function() {
    ok(exists(".topic-list"), "The list of topics was rendered");
    ok(exists('.topic-list .topic-list-item'), "has topics");
    // TODO enable test once fixed
    // ok($('body.category-bug').length, "has a custom css class for the category id on the body");
  });

  visit("/categories");
  andThen(function() {
    ok($('body.category-bug').length === 0, "removes the custom category class");

    ok(exists('.category'), "has a list of categories");
    ok($('body.categories-list').length, "has a custom class to indicate categories");
  });

  visit("/top");
  andThen(function() {
    ok($('body.categories-list').length === 0, "removes the `categories-list` class");
    ok(exists('.topic-list .topic-list-item'), "has topics");
  });
});
