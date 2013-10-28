integration("View Topic");

test("Enter a Topic", function() {
  expect(2);

  visit("/t/internationalization-localization/280").then(function() {
    ok(exists("#topic"), "The was rendered");
    ok(exists("#topic .topic-post"), "The topic has posts");
  });
});
