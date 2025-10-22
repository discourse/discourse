import { click, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import ReactionsTopics from "../fixtures/reactions-topic-fixtures";

["enabled", "disabled"].forEach((postStreamMode) => {
  acceptance(
    `Discourse Reactions - Custom Emoji Picker (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.user();

      needs.settings({
        discourse_reactions_enabled: true,
        discourse_reactions_enabled_reactions: "otter|open_mouth|heart",
        discourse_reactions_reaction_for_like: "heart",
        discourse_reactions_like_icon: "heart",
        discourse_reactions_experimental_allow_any_emoji: true,
        glimmer_post_stream_mode: postStreamMode,
      });

      needs.pretender((server, helper) => {
        const topicPath = "/t/374.json";
        server.get(topicPath, () =>
          helper.response(ReactionsTopics[topicPath])
        );

        server.put(
          "/discourse-reactions/posts/:post_id/custom-reaction/:reaction",
          () => helper.response({ success: true })
        );

        server.put(
          "/discourse-reactions/posts/:post_id/custom-reactions/:reaction/toggle.json",
          () => helper.response({ success: "OK" })
        );
      });

      test("Shows EmojiPicker button when discourse_reactions_experimental_allow_any_emoji is enabled", async function (assert) {
        await visit("/t/topic_with_reactions_and_likes/374");
        await triggerEvent(
          "#post_2 button.btn-toggle-reaction-like",
          "pointerover",
          { pointerType: "mouse" }
        );

        assert
          .dom(".emoji-picker-trigger")
          .exists("EmojiPicker button exists in reactions picker");
      });

      test("Clicking EmojiPicker prevents reactions picker from collapsing", async function (assert) {
        await visit("/t/topic_with_reactions_and_likes/374");
        await triggerEvent(
          "#post_2 button.btn-toggle-reaction-like",
          "pointerover",
          { pointerType: "mouse" }
        );

        await click(".emoji-picker-trigger");

        await triggerEvent("#site-logo", "pointerover", {
          pointerType: "mouse",
        });
        await new Promise((resolve) => setTimeout(resolve, 1000));
        assert
          .dom(".discourse-reactions-picker.is-expanded")
          .exists(
            "Reactions picker remains expanded even if mouse moving outside when EmojiPicker is open"
          );

        await click("#post_4 .post-avatar");

        assert
          .dom(".discourse-reactions-picker.is-expanded")
          .exists(
            "Reactions picker remains expanded even if mouse clicking outside when EmojiPicker is open"
          );
      });

      test("Selected custom emoji is added to reactions when discourse_reactions_experimental_allow_any_emoji is enabled", async function (assert) {
        await visit("/t/topic_with_reactions_and_likes/374");
        await triggerEvent(
          "#post_2 button.btn-toggle-reaction-like",
          "pointerover",
          { pointerType: "mouse" }
        );
        await click(".emoji-picker-trigger");
        await click('img.emoji[alt="grinning"]');
        // Assert the reactions list emoji on the left
        assert
          .dom('#post_2 .discourse-reactions-list-emoji img[alt="grinning"]')
          .exists("Grinning emoji exists in reactions list");

        // Assert the reaction button emoji
        assert
          .dom('#post_2 .btn.reaction-button img[alt=":grinning"]')
          .exists("Grinning emoji exists in reaction button");
      });
    }
  );

  acceptance(
    `Discourse Reactions - Custom Emoji Picker Disabled (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.user();

      needs.settings({
        discourse_reactions_enabled: true,
        discourse_reactions_enabled_reactions: "otter|open_mouth|heart",
        discourse_reactions_reaction_for_like: "heart",
        discourse_reactions_like_icon: "heart",
        discourse_reactions_experimental_allow_any_emoji: false,
        glimmer_post_stream_mode: postStreamMode,
      });

      needs.pretender((server, helper) => {
        const topicPath = "/t/374.json";
        server.get(topicPath, () =>
          helper.response(ReactionsTopics[topicPath])
        );

        server.put(
          "/discourse-reactions/posts/:post_id/custom-reactions/:reaction/toggle.json",
          () => helper.response({ success: "OK" })
        );
      });

      test("Does not show EmojiPicker button when discourse_reactions_experimental_allow_any_emoji is disabled", async function (assert) {
        await visit("/t/topic_with_reactions_and_likes/374");
        await triggerEvent(
          "#post_2 button.btn-toggle-reaction-like",
          "pointerover",
          { pointerType: "mouse" }
        );

        assert
          .dom(".emoji-picker-trigger")
          .doesNotExist(
            "EmojiPicker button does not exist when setting is disabled"
          );
      });

      test("Reactions picker grid only counts enabled reactions when EmojiPicker is disabled", async function (assert) {
        await visit("/t/topic_with_reactions_and_likes/374");
        await triggerEvent(
          "#post_2 button.btn-toggle-reaction-like",
          "pointerover",
          { pointerType: "mouse" }
        );

        // With 3 enabled reactions and no emoji picker button = 3 total
        assert
          .dom(".discourse-reactions-picker-container")
          .hasClass("col-3", "Grid has 3 columns without EmojiPicker button");
      });
    }
  );
});
