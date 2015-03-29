integration("Groups");

test("Browsing Groups", () => {
  visit("/groups/discourse");
  andThen(() => {
    ok(count('.user-stream .item') > 0, "it has stream items");
  });

  visit("/groups/discourse/members");
  andThen(() => {
    ok(count('.group-members tr') > 0, "it lists group members");
  });
});
