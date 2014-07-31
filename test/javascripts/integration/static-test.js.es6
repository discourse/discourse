integration("Static");

test("Static Pages", function() {
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

  visit("/login");
  andThen(function() {
    equal(currentPath(), "discovery.latest", "it redirects them to latest unless `login_required`");
  });
});
