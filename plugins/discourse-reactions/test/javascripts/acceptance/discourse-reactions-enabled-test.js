import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { default as ReactionsTopics } from "../fixtures/reactions-topic-fixtures";

["enabled", "disabled"].forEach((postStreamMode) => {
  acceptance(
    `Discourse Reactions - Enabled (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.user();

      needs.settings({
        discourse_reactions_enabled: true,
        discourse_reactions_enabled_reactions: "otter|open_mouth",
        discourse_reactions_reaction_for_like: "heart",
        discourse_reactions_like_icon: "heart",
        glimmer_post_stream_mode: postStreamMode,
      });

      needs.pretender((server, helper) => {
        const topicPath = "/t/374.json";
        server.get(topicPath, () =>
          helper.response(ReactionsTopics[topicPath])
        );
      });

      test("It shows reactions controls", async (assert) => {
        await visit("/t/topic_with_reactions_and_likes/374");

        assert.ok(
          exists(".discourse-reactions-actions"),
          "reaction controls are available"
        );
      });
    }
  );

  acceptance(
    `Discourse Reactions - Enabled | Anonymous user (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.settings({
        discourse_reactions_enabled: true,
        discourse_reactions_enabled_reactions: "otter|open_mouth",
        discourse_reactions_reaction_for_like: "heart",
        discourse_reactions_like_icon: "heart",
        glimmer_post_stream_mode: postStreamMode,
      });

      needs.pretender((server, helper) => {
        const topicPath = "/t/374.json";
        server.get(topicPath, () =>
          helper.response(ReactionsTopics[topicPath])
        );
      });

      test("It shows reactions controls", async (assert) => {
        await visit("/t/topic_with_reactions_and_likes/374");
        await click(".actions button.btn-toggle-reaction-like");

        assert.dom("#login-form").exists("login form was displayed");
      });
    }
  );
});
