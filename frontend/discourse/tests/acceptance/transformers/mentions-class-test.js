import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("mentions-class transformer", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/t/280.json", () => {
      const topic = cloneJSON(topicFixtures["/t/280/1.json"]);
      topic.post_stream.posts[0].cooked =
        '<p>Hello <a class="mention" href="/u/system">@system</a>, welcome!</p>';
      topic.post_stream.posts[0].mentioned_users = [
        { id: -1, username: "system" },
      ];
      return helper.response(topic);
    });
  });

  test("applying a value transformation", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert.dom("a.mention[href='/u/system']").hasClass("--bot");
  });
});
