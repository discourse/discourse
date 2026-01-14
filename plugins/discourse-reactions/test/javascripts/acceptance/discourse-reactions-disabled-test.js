import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import ReactionsTopics from "../fixtures/reactions-topic-fixtures";

acceptance(`Discourse Reactions - Disabled`, function (needs) {
  needs.user();

  needs.settings({
    discourse_reactions_enabled: false,
  });

  needs.pretender((server, helper) => {
    const topicPath = "/t/374.json";
    server.get(topicPath, () => helper.response(ReactionsTopics[topicPath]));
  });

  test("Does not show reactions controls", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom(".discourse-reactions-actions")
      .doesNotExist("reactions controls are not shown");
  });
});
