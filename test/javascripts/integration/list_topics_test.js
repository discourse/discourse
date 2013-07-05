integration("List Topics");

test("Default List", function() {
  expect(2);

  visit("/").then(function() {
    ok(exists("#topic-list"), "The list of topics was rendered");
    ok(exists('#topic-list .topic-list-item'), "has topics");
  });
});

test("List one Category", function() {
  expect(2);

  visit("/category/bug").then(function() {
    ok(exists("#topic-list"), "The list of topics was rendered");
    ok(exists('#topic-list .topic-list-item'), "has topics");
  });
});

test("Categories List", function() {
  expect(1);

  visit("/categories").then(function() {
    ok(exists('.category-list-item'), "has a list of categories");
  });
});



