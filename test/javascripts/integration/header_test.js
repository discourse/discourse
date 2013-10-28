integration("Header");

test("/", function() {
  expect(2);

  visit("/").then(function() {
    ok(exists("header"), "The header was rendered");
    ok(exists("#site-logo"), "The logo was shown");
  });
});
