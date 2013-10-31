integration("Header");

test("header", function() {
  expect(1);

  visit("/").then(function() {
    ok(exists("header"), "is rendered");
  });
});

test("logo", function() {
  expect(2);

  visit("/").then(function() {
    ok(exists(".logo-big"), "is rendered");

    Ember.run(function() {
      controllerFor("header").set("showExtraInfo", true);
    });
    ok(exists(".logo-small"), "is properly wired to showExtraInfo property (when showExtraInfo value changes, logo size also changes)");
  });
});
