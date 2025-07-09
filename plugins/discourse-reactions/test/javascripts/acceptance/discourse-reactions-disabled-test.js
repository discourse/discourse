import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { default as ReactionsTopics } from "../fixtures/reactions-topic-fixtures";

["enabled", "disabled"].forEach((postStreamMode) => {
  acceptance(
    `Discourse Reactions - Disabled (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.user();

      needs.settings({
        discourse_reactions_enabled: false,
        glimmer_post_stream_mode: postStreamMode,
      });

      needs.pretender((server, helper) => {
        const topicPath = "/t/374.json";
        server.get(topicPath, () =>
          helper.response(ReactionsTopics[topicPath])
        );
      });

      test("Does not show reactions controls", async (assert) => {
        await visit("/t/topic_with_reactions_and_likes/374");

        assert.notOk(
          exists(".discourse-reactions-actions"),
          "reactions controls are not shown"
        );
      });
    }
  );
});
