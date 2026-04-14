import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import ReactionsTopics from "../fixtures/reactions-topic-fixtures";

acceptance(`Discourse Reactions - Archived topic`, function (needs) {
  needs.user();

  needs.settings({
    discourse_reactions_enabled: true,
    discourse_reactions_enabled_reactions: "otter|open_mouth",
    discourse_reactions_reaction_for_like: "heart",
    discourse_reactions_like_icon: "heart",
  });

  needs.pretender((server, helper) => {
    const topicPath = "/t/374.json";
    const topicData = structuredClone(ReactionsTopics[topicPath]);

    // Make topic archived
    topicData.archived = true;

    // Ensure post_2 (id 1076) has no like action and no reactions
    const post2 = topicData.post_stream.posts.find((p) => p.id === 1076);
    post2.actions_summary = post2.actions_summary.filter((a) => a.id !== 2);
    post2.reactions = [];
    post2.current_user_reaction = null;
    post2.reaction_users_count = 0;
    post2.current_user_used_main_reaction = false;

    server.get(topicPath, () => helper.response(topicData));

    server.put(
      "/discourse-reactions/posts/:post_id/custom-reactions/:reaction/toggle.json",
      () => helper.response(403, { errors: ["forbidden"] })
    );
  });

  test("Cannot toggle reaction on post with no likes in archived topic", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom("#post_2 .discourse-reactions-actions.can-toggle-reaction")
      .doesNotExist("reaction button is not toggleable");

    assert
      .dom("#post_2 .discourse-reactions-reaction-button")
      .exists("reaction button is rendered");

    await click("#post_2 .discourse-reactions-reaction-button");

    assert
      .dom(".dialog-body")
      .doesNotExist("no error dialog is shown after clicking");

    assert
      .dom("#post_2 .discourse-reactions-actions.has-reacted")
      .doesNotExist("no reaction was applied optimistically");
  });
});
