import { acceptance } from "helpers/qunit-helpers";
acceptance("About");

test("viewing", () => {
  visit("/about");
  andThen(() => {
    ok(exists('.about.admins .user-info'), 'has admins');
    ok(exists('.about.moderators .user-info'), 'has moderators');
    ok(exists('.about.stats tr td'), 'has stats');
  });
});

