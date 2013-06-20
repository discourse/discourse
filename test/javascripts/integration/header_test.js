integration("Header");

test("/", function() {

  visit("/").then(function() {
    expect(2);

    ok(exists("header"), "The header was rendered");
    ok(exists("#site-logo"), "The logo was shown");
  });

});


