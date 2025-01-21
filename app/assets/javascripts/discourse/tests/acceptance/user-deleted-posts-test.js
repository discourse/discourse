import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import postFixtures from "discourse/tests/fixtures/post";
import { acceptance } from "../helpers/qunit-helpers";

acceptance("User's deleted posts page", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get(`/posts/eviltrout/deleted`, () => {
      const post1 = cloneJSON(postFixtures["/posts/398"]);
      post1.excerpt = "Topic #1";
      const post2 = cloneJSON(postFixtures["/posts/98737532"]);
      post2.excerpt = "Another topic's text";

      return helper.response([post1, post2]);
    });
  });

  test("Displays the posts", async function (assert) {
    await visit(`/u/eviltrout/deleted-posts`);

    assert.dom(".user-stream-item [data-topic-id='280']").hasText("Topic #1");
    assert
      .dom(".user-stream-item [data-topic-id='34']")
      .hasText("Another topic's text");
  });
});
