integration("List Topics");

test("Default List", function() {

  visit("/").then(function() {
    expect(2);

    ok(exists("#topic-list"), "The list of topics was rendered");
    ok(exists('#topic-list .topic-list-item'), "has topics");
  });

});

test("Categories List", function() {

  visit("/categories").then(function() {
    expect(1);

    ok(exists('.category-list-item'), "has a list of categories");
  });

});



