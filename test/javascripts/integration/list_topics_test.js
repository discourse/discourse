integration("List Topics");

test("/", function() {

  visit("/").then(function() {
    expect(2);

    ok(exists("#topic-list"), "The list of topics was rendered");
    ok(count('#topic-list .topic-list-item') > 0, "has topics");
  });

});


