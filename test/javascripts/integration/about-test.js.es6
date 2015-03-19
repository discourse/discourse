integration("About");

test("viewing", () => {
  visit("/about");
  andThen(() => {
    ok(exists('.about.admins .user-small'), 'has admins');
    ok(exists('.about.moderators .user-small'), 'has moderators');
    ok(exists('.about.stats tr td'), 'has stats');
  });
});

