integration("User Directory");

test("Visit Page", () => {
  visit("/directory/all");
  andThen(() => {
    ok(exists('.directory table tr'), "has a list of users");
  });
});
