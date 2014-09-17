integration("View Topic");

test("Enter a Topic", function() {
  visit("/t/internationalization-localization/280");
  andThen(function() {
    ok(exists("#topic"), "The topic was rendered");
    ok(exists("#topic .post-cloak"), "The topic has cloaked posts");
  });
});

test("Enter without an id", function() {
  visit("/t/internationalization-localization");
  andThen(function() {
    ok(exists("#topic"), "The topic was rendered");
  });
});
