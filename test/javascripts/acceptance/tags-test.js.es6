import { acceptance } from "helpers/qunit-helpers";
acceptance("Tags", { loggedIn: true });

QUnit.test("list the tags", assert => {
  visit("/tags");

  andThen(() => {
    assert.ok($('body.tags-page').length, "has the body class");
    assert.ok(exists('.tag-eviltrout'), "shows the evil trout tag");
  });
});