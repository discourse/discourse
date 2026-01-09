import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import ReactionsTopics from "../fixtures/reactions-topic-fixtures";

acceptance(`Discourse Reactions - Post`, function (needs) {
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

  test("Reactions count", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom("#post_1 .discourse-reactions-counter .reactions-counter")
      .hasText("209", "displays the correct count");
  });

  test("Other user post", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom("#post_2 .discourse-reactions-reaction-button")
      .exists("displays the reaction button");
  });

  test("Post is yours", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom("#post_1 .discourse-reactions-reaction-button")
      .doesNotExist("does not display the reaction button");
  });

  test("Post has only likes (no reactions)", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom("#post_3 .discourse-reactions-double-button")
      .exists("displays the reaction count beside the reaction button");
  });

  test("Post has likes and reactions", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom("#post_1 .discourse-reactions-double-button")
      .doesNotExist(
        "does not display the reaction count beside the reaction button"
      );
  });

  test("Current user has no reaction on post and can toggle", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom("#post_2 .discourse-reactions-actions.can-toggle-reaction")
      .exists("allows to toggle the reaction");
  });

  test("Current user has no reaction on post and can toggle", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom("#post_2 .discourse-reactions-actions.can-toggle-reaction")
      .exists("allows to toggle the reaction");
  });

  test("Current user can undo on post and can toggle", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom("#post_3 .discourse-reactions-actions.can-toggle-reaction")
      .exists("allows to toggle the reaction");
  });

  test("Current user can't toggle", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom("#post_1 .discourse-reactions-actions.can-toggle-reaction")
      .doesNotExist("doesn’t allow to toggle the reaction");
  });
});
