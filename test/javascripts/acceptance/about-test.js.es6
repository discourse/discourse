import { acceptance } from "helpers/qunit-helpers";
acceptance("About");

test("viewing", () => {
  visit("/about");
  andThen(() => {
    ok($('body.about-page').length, "has body class");
    ok(exists('.about.admins .user-info'), 'has admins');
    ok(exists('.about.moderators .user-info'), 'has moderators');
    ok(exists('.about.stats tr td'), 'has stats');
  });
});

