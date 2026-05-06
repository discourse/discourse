import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import ReactionsTopics from "../fixtures/reactions-topic-fixtures";

function makeUser(id, reaction) {
  return {
    id,
    username: `u${id}`,
    name: `User ${id}`,
    avatar_template: "/user_avatar/avatar/{size}/1_1.png",
    reaction,
  };
}

const SETTINGS = {
  discourse_reactions_enabled: true,
  discourse_reactions_enabled_reactions: "laughing|open_mouth",
  discourse_reactions_reaction_for_like: "heart",
  discourse_reactions_like_icon: "heart",
  enable_new_post_reactions_menu: true,
};

acceptance(
  "Discourse Reactions - Users menu caches when total fits in one page",
  function (needs) {
    needs.user();
    needs.settings(SETTINGS);

    let fetchCount = 0;
    let lastReactionValue;

    needs.hooks.beforeEach(() => {
      fetchCount = 0;
      lastReactionValue = undefined;
    });

    needs.pretender((server, helper) => {
      server.get("/t/374.json", () =>
        helper.response(ReactionsTopics["/t/374.json"])
      );

      server.get(
        "/discourse-reactions/posts/:id/reactions-users-list.json",
        (request) => {
          fetchCount++;
          lastReactionValue = request.queryParams.reaction_value;

          const allUsers = [
            makeUser(1, "heart"),
            makeUser(2, "heart"),
            makeUser(3, "heart"),
            makeUser(4, "laughing"),
            makeUser(5, "laughing"),
          ];

          return helper.response({ users: allUsers, total_rows: 5 });
        }
      );
    });

    test("filters cached users client-side when switching tabs", async function (assert) {
      await visit("/t/topic_with_reactions_and_likes/374");
      await click("#post_1 .discourse-reactions-counter");

      assert.strictEqual(fetchCount, 1, "fetches once when opening the menu");
      assert.strictEqual(
        lastReactionValue,
        undefined,
        "first fetch has no reaction_value"
      );
      assert.dom(".post-users-popup__item").exists({ count: 5 });

      await click('[data-reaction-filter="heart"]');
      assert.strictEqual(
        fetchCount,
        1,
        "does not refetch when filtering by heart"
      );
      assert.dom(".post-users-popup__item").exists({ count: 3 });

      await click('[data-reaction-filter="laughing"]');
      assert.strictEqual(
        fetchCount,
        1,
        "does not refetch when filtering by laughing"
      );
      assert.dom(".post-users-popup__item").exists({ count: 2 });

      await click('[data-reaction-filter="all"]');
      assert.strictEqual(
        fetchCount,
        1,
        "does not refetch when returning to all"
      );
      assert.dom(".post-users-popup__item").exists({ count: 5 });
    });
  }
);

acceptance(
  "Discourse Reactions - Users menu fetches per tab when total exceeds one page",
  function (needs) {
    needs.user();
    needs.settings(SETTINGS);

    let fetchCount = 0;
    let lastReactionValue;

    needs.hooks.beforeEach(() => {
      fetchCount = 0;
      lastReactionValue = undefined;
    });

    needs.pretender((server, helper) => {
      server.get("/t/374.json", () =>
        helper.response(ReactionsTopics["/t/374.json"])
      );

      server.get(
        "/discourse-reactions/posts/:id/reactions-users-list.json",
        (request) => {
          fetchCount++;
          lastReactionValue = request.queryParams.reaction_value;

          const pageUsers = Array.from({ length: 30 }, (_, i) =>
            makeUser(i + 1, i < 25 ? "heart" : "laughing")
          );

          return helper.response({ users: pageUsers, total_rows: 45 });
        }
      );
    });

    test("fetches once per tab and serves cached tabs on return", async function (assert) {
      await visit("/t/topic_with_reactions_and_likes/374");
      await click("#post_1 .discourse-reactions-counter");

      assert.strictEqual(fetchCount, 1, "fetches once when opening the menu");

      await click('[data-reaction-filter="laughing"]');
      assert.strictEqual(fetchCount, 2, "fetches when opening laughing tab");
      assert.strictEqual(
        lastReactionValue,
        "laughing",
        "second fetch sends reaction_value=laughing"
      );

      await click('[data-reaction-filter="all"]');
      assert.strictEqual(
        fetchCount,
        2,
        "does not refetch when returning to a previously-loaded tab"
      );

      await click('[data-reaction-filter="laughing"]');
      assert.strictEqual(fetchCount, 2, "does not refetch laughing tab either");
    });
  }
);
