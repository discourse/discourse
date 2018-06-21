import { acceptance } from "helpers/qunit-helpers";
acceptance("About");

QUnit.test("viewing", assert => {
  visit("/about");
  andThen(() => {
    assert.ok($("body.about-page").length, "has body class");
    assert.ok(exists(".about.admins .user-info"), "has admins");
    assert.ok(exists(".about.moderators .user-info"), "has moderators");
    assert.ok(exists(".about.stats tr td"), "has stats");
  });
});
