import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { default as ReactionsTopics } from "../fixtures/reactions-topic-fixtures";

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

  test("Reaction controls", async (assert) => {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert.notOk(
      exists("#post_4 .discourse-reactions-actions"),
      "reaction controls are not shown"
    );
  });
});
