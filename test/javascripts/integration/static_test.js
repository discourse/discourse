integration("Static");

test("Faq", function() {
  expect(1);
  visit("/faq").then(function() {
    ok(exists(".body-page"), "The content is present");
  });
});

test("Terms of Service", function() {
  expect(1);
  visit("/tos").then(function() {
    ok(exists(".body-page"), "The content is present");
  });
});

test("Privacy", function() {
  expect(1);
  visit("/privacy").then(function() {
    ok(exists(".body-page"), "The content is present");
  });
});
