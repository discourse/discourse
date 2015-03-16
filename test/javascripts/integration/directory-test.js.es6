integration("User Directory");

test("Visit Page", function() {
  visit("/directory/all");
  andThen(function() {
    ok(exists('.directory table tr'), "has a list of users");
  });
});
