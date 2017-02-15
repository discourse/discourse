import { acceptance } from "helpers/qunit-helpers";
acceptance("Tags", { loggedIn: true });

test("list the tags", () => {
  visit("/tags");

  andThen(() => {
    ok($('body.tags-page').length, "has the body class");
    ok(exists('.tag-eviltrout'), "shows the evil trout tag");
  });
});
