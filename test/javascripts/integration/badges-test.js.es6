integration("Badges");

test("Visit Badge Pages", function() {
  visit("/badges");
  andThen(function() {
    ok(exists('.badges-listing tr'), "has a list of badges");
  });

  visit("/badges/9/autobiographer");
  andThen(function() {
    ok(exists('.badges-listing tr'), "has the badge in the listing");
    ok(exists('.badge-user'), "has the list of users with that badge");
  });
});
