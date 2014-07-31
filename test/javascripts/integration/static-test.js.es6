integration("Static");

test("Static Pages", function() {
  expect(4);
  visit("/faq");
  andThen(function() {
    ok(exists(".body-page"), "The content is present");
  });
  visit("/guidelines");
  andThen(function() {
    ok(exists(".body-page"), "The content is present");
  });
  visit("/tos");
  andThen(function() {
    ok(exists(".body-page"), "The content is present");
  });
  visit("/privacy");
  andThen(function() {
    ok(exists(".body-page"), "The content is present");
  });
});
