import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import ReactionsTopics from "../fixtures/reactions-topic-fixtures";

acceptance(`Discourse Reactions - Icon Aliases`, function (needs) {
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

  test("uses d-liked alias when user has reacted with default heart icon", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom("#post_3 .discourse-reactions-reaction-button .d-icon-d-liked")
      .exists(
        "reaction button uses d-liked alias when user has reacted with heart"
      );
  });

  test("uses d-unliked alias when user has not reacted with default heart icon", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom("#post_2 .discourse-reactions-reaction-button .d-icon-d-unliked")
      .exists(
        "reaction button uses d-unliked alias when user has not reacted with heart"
      );
  });
});
