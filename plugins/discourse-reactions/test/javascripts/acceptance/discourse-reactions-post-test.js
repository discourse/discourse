/* eslint-disable qunit/no-assert-equal */
/* eslint-disable qunit/no-loose-assertions */
import { visit } from "@ember/test-helpers";
import { skip, test } from "qunit";
import {
  acceptance,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { default as ReactionsTopics } from "../fixtures/reactions-topic-fixtures";

["enabled", "disabled"].forEach((postStreamMode) => {
  acceptance(
    `Discourse Reactions - Post (glimmer_post_stream_mode = ${postStreamMode})`,
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

      test("Reactions count", async (assert) => {
        await visit("/t/topic_with_reactions_and_likes/374");

        assert.equal(
          queryAll(
            "#post_1 .discourse-reactions-counter .reactions-counter"
          ).text(),
          209,
          "it displays the correct count"
        );
      });

      skip("Reactions list", async (assert) => {
        const reactions = [];
        const expectedSequence =
          "heart|angry|laughing|open_mouth|cry|thumbsdown|nose:t2|thumbsup";

        await visit("/t/topic_with_reactions_and_likes/374");

        queryAll(
          "#post_1 .discourse-reactions-counter .discourse-reactions-list .reactions .discourse-reactions-list-emoji"
        ).map((index, currentValue) => {
          reactions.push(currentValue.innerText);
        });

        assert.equal(
          reactions.join("|"),
          expectedSequence,
          "it displays the correct list sorted by count"
        );
      });

      test("Other user post", async (assert) => {
        await visit("/t/topic_with_reactions_and_likes/374");

        assert.ok(
          exists("#post_2 .discourse-reactions-reaction-button"),
          "it displays the reaction button"
        );
      });

      test("Post is yours", async (assert) => {
        await visit("/t/topic_with_reactions_and_likes/374");

        assert.notOk(
          exists("#post_1 .discourse-reactions-reaction-button"),
          "it does not display the reaction button"
        );
      });

      test("Post has only likes (no reactions)", async (assert) => {
        await visit("/t/topic_with_reactions_and_likes/374");

        assert.ok(
          exists("#post_3 .discourse-reactions-double-button"),
          "it displays the reaction count beside the reaction button"
        );
      });

      test("Post has likes and reactions", async (assert) => {
        await visit("/t/topic_with_reactions_and_likes/374");

        assert.notOk(
          exists("#post_1 .discourse-reactions-double-button"),
          "it does not display the reaction count beside the reaction button"
        );
      });

      test("Current user has no reaction on post and can toggle", async (assert) => {
        await visit("/t/topic_with_reactions_and_likes/374");

        assert.ok(
          exists("#post_2 .discourse-reactions-actions.can-toggle-reaction"),
          "it allows to toggle the reaction"
        );
      });

      test("Current user has no reaction on post and can toggle", async (assert) => {
        await visit("/t/topic_with_reactions_and_likes/374");

        assert.ok(
          exists("#post_2 .discourse-reactions-actions.can-toggle-reaction"),
          "it allows to toggle the reaction"
        );
      });

      test("Current user can undo on post and can toggle", async (assert) => {
        await visit("/t/topic_with_reactions_and_likes/374");

        assert.ok(
          exists("#post_3 .discourse-reactions-actions.can-toggle-reaction"),
          "it allows to toggle the reaction"
        );
      });

      test("Current user can't toggle", async (assert) => {
        await visit("/t/topic_with_reactions_and_likes/374");

        assert.notOk(
          exists("#post_1 .discourse-reactions-actions.can-toggle-reaction"),
          "it doesn’t allow to toggle the reaction"
        );
      });
    }
  );
});
