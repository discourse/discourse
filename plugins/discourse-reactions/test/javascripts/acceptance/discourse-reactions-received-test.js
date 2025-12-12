import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Discourse Reactions - Reactions Received Page", function (needs) {
  needs.user();

  needs.settings({
    discourse_reactions_enabled: true,
    discourse_reactions_enabled_reactions: "otter|open_mouth|heart",
    discourse_reactions_reaction_for_like: "heart",
  });

  needs.pretender((server, helper) => {
    server.get("/discourse-reactions/posts/reactions-received.json", () => {
      return helper.response([
        {
          id: 1,
          user_id: 1,
          post_id: 123,
          reaction: {
            reaction_value: "heart",
            reaction_users_count: 1,
          },
          post: {
            id: 123,
            created_at: "2024-01-01T00:00:00.000Z",
            topic_id: 1,
            topic_title: "Test Topic",
            topic_slug: "test-topic",
            topic_html_title: "Test Topic",
            post_number: 1,
            posts_count: 5,
            post_type: 1,
            excerpt:
              'This is a post with a mention <span class="mention">@keegan</span> in it.',
            expandedExcerpt:
              'This is a post with a mention <span class="mention">@keegan</span> in it. More content here.',
            url: "/t/test-topic/1/1",
            category_id: 1,
            user_id: 3,
            username: "testuser",
            name: "Test User",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/t/3be4f8/{size}.png",
            user: {
              id: 3,
              username: "testuser",
              name: "Test User",
              avatar_template:
                "/letter_avatar_proxy/v4/letter/t/3be4f8/{size}.png",
            },
            topic: {
              id: 1,
              title: "Test Topic",
              fancy_title: "Test Topic",
              slug: "test-topic",
              posts_count: 5,
            },
          },
          user: {
            id: 2,
            username: "reactor",
            name: "Reactor User",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/r/3be4f8/{size}.png",
            userUrl: "/u/reactor",
          },
          created_at: "2024-01-01T00:00:00.000Z",
        },
      ]);
    });
  });

  test("mentions display with username, not full name", async function (assert) {
    await visit("/u/eviltrout/notifications/reactions-received");

    assert
      .dom(".post-list-item .excerpt .mention")
      .hasText("@keegan", "mention displays username, not full name");
  });

  test("mentions have proper structure for user cards", async function (assert) {
    await visit("/u/eviltrout/notifications/reactions-received");

    assert
      .dom(".post-list-item .excerpt .mention")
      .exists("mention span exists");

    const mentionText = document
      .querySelector(".post-list-item .excerpt .mention")
      ?.textContent?.trim();

    assert.true(mentionText?.startsWith("@"), "mention starts with @");

    assert.false(
      mentionText?.includes(" "),
      "mention does not contain spaces (which would indicate a full name)"
    );
  });
});
