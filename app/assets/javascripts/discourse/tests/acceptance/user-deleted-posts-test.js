import { acceptance } from "../helpers/qunit-helpers";
import { test } from "qunit";
import postFixtures from "discourse/tests/fixtures/post";
import { visit } from "@ember/test-helpers";

acceptance("User's deleted posts page", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get(`/posts/eviltrout/deleted`, () => {
      return helper.response([
        postFixtures["/posts/398"],
        postFixtures["/posts/98737532"],
      ]);
    });
  });

  test("Displays the posts", async function (assert) {
    await visit(`/u/eviltrout/deleted-posts`);
    assert.dom(".user-stream-item").exists({ count: 2 });
  });
});
