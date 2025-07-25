import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import ReactionsTopics from "../fixtures/reactions-topic-fixtures";

acceptance("Discourse Reactions - Deleted post", function (needs) {
  needs.user();

  needs.settings({
    discourse_reactions_enabled: true,
    discourse_reactions_enabled_reactions: "otter|open_mouth",
    discourse_reactions_reaction_for_like: "heart",
    discourse_reactions_like_icon: "heart",
  });

  needs.pretender((server, helper) => {
    const topicPath = "/t/374.json";
    server.get(topicPath, () => helper.response(ReactionsTopics[topicPath]));
  });

  test("Reaction controls", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom("#post_4 .discourse-reactions-actions")
      .doesNotExist("reaction controls are not shown");
  });
});
