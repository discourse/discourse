import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import ReactionsTopics from "../fixtures/reactions-topic-fixtures";

acceptance("Post", function (needs) {
  needs.user();

  needs.settings({
    discourse_reactions_enabled: true,
    discourse_reactions_enabled_reactions: "otter|open_mouth",
    discourse_reactions_reaction_for_like: "heart",
    discourse_reactions_like_icon: "heart",
    enable_new_post_reactions_menu: true,
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
      .dom("#post_3 .discourse-reactions-counter .reactions-counter")
      .hasText("2", "displays the like count in the counter");
  });

  test("Post has likes and reactions", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom("#post_1 .discourse-reactions-list .discourse-reactions-list-emoji")
      .exists(
        { count: 8 },
        "renders an emoji for each reaction in the counter list"
      );
  });

  test("Reaction emoji shows its name in the title on hover", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom("#post_1 .discourse-reactions-list-emoji img[alt='laughing']")
      .hasAttribute(
        "title",
        "laughing",
        "sets the emoji name as the title attribute"
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

acceptance("Post - hidden reactions", function (needs) {
  needs.user();

  needs.settings({
    discourse_reactions_enabled: true,
    discourse_reactions_enabled_reactions: "otter|open_mouth",
    discourse_reactions_reaction_for_like: "heart",
    discourse_reactions_like_icon: "heart",
    enable_new_post_reactions_menu: true,
  });

  needs.pretender((server, helper) => {
    const topic = structuredClone(ReactionsTopics["/t/374.json"]);
    const post = topic.post_stream.posts[0];
    // A staff member or the author can always see a hidden post, so the denied
    // case is only reachable for a non-owner, non-staff viewer.
    post.yours = false;
    post.admin = false;
    post.staff = false;
    post.moderator = false;
    post.user_id = 999;
    post.hidden = true;
    post.cooked_hidden = true;
    post.can_see_hidden_post = false;

    server.get("/t/374.json", () => helper.response(topic));
  });

  test("hides reaction affordances for hidden posts", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom("#post_1 .discourse-reactions-counter")
      .doesNotExist("hides the counter to prevent opening the reactions list");

    assert
      .dom("#post_1 .discourse-reactions-reaction-button")
      .doesNotExist("hides the reaction button that would hit a 403");
  });
});

acceptance("Post - hidden reactions with hidden-post access", function (needs) {
  needs.user();

  needs.settings({
    discourse_reactions_enabled: true,
    discourse_reactions_enabled_reactions: "otter|open_mouth",
    discourse_reactions_reaction_for_like: "heart",
    discourse_reactions_like_icon: "heart",
    enable_new_post_reactions_menu: true,
  });

  needs.pretender((server, helper) => {
    const topic = structuredClone(ReactionsTopics["/t/374.json"]);
    const post = topic.post_stream.posts[0];
    post.yours = false;
    post.admin = false;
    post.staff = false;
    post.moderator = false;
    post.user_id = 999;
    post.hidden = true;
    post.can_see_hidden_post = true;

    server.get("/t/374.json", () => helper.response(topic));
  });

  test("keeps reaction affordances for hidden posts", async function (assert) {
    await visit("/t/topic_with_reactions_and_likes/374");

    assert
      .dom("#post_1 .discourse-reactions-counter .reactions-counter")
      .hasText("209", "allows the reactions list to be opened");

    assert
      .dom("#post_1 .discourse-reactions-reaction-button")
      .exists("keeps the reaction button for viewers who can see the post");
  });
});
