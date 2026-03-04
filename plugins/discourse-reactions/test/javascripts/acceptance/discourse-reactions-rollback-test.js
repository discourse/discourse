import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import ReactionsTopics from "../fixtures/reactions-topic-fixtures";

acceptance("Discourse Reactions - API Error Rollback", function (needs) {
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

    server.put(
      "/discourse-reactions/posts/:post_id/custom-reactions/:reaction/toggle.json",
      () => helper.response(403, { errors: ["forbidden"] })
    );
  });

  test("reverts reaction state when API call fails", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    const initialCount = document
      .querySelector("#post_2 .reactions-counter")
      ?.textContent?.trim();

    await click("#post_2 .btn-toggle-reaction-like");

    const finalCount = document
      .querySelector("#post_2 .reactions-counter")
      ?.textContent?.trim();

    assert.strictEqual(
      finalCount,
      initialCount,
      "reaction count reverts after API failure"
    );
  });
});
