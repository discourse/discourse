integration("Groups");

test("Browsing Groups", function() {
  visit("/groups/discourse");
  andThen(function() {
    ok(count('.user-stream .item') > 0, "it has stream items");
  });
  visit("/groups/discourse/members");
  andThen(function() {
    ok(count('.group-members tr') > 0, "it lists group members");
  });
});
