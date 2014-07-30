integration("Topic Discovery");

test("Visit Discovery Pages", function() {
  expect(5);

  visit("/");
  andThen(function() {
    ok(exists(".topic-list"), "The list of topics was rendered");
    ok(exists('.topic-list .topic-list-item'), "has topics");
  });

  visit("/category/bug");
  andThen(function() {
    ok(exists(".topic-list"), "The list of topics was rendered");
    ok(exists('.topic-list .topic-list-item'), "has topics");
  });

  visit("/categories");
  andThen(function() {
    ok(exists('.category'), "has a list of categories");
  });
});
