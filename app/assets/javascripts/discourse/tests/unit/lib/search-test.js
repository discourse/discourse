import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  reciprocallyRankedList,
  searchContextDescription,
  translateResults,
} from "discourse/lib/search";
import I18n from "discourse-i18n";

module("Unit | Utility | search", function (hooks) {
  setupTest(hooks);

  test("unescapesEmojisInBlurbs", async function (assert) {
    const source = {
      posts: [
        {
          id: 160,
          username: "pmusaraj",
          avatar_template: "/user_avatar/localhost/pmusaraj/{size}/3_2.png",
          created_at: "2019-07-22T03:47:04.864Z",
          like_count: 1,
          blurb: ":thinking: This here is a test of emojis in search blurbs.",
          post_number: 1,
          topic_id: 41,
        },
      ],
      topics: [],
      users: [],
      categories: [],
      tags: [],
      groups: [],
      grouped_search_result: false,
    };

    const results = await translateResults(source);
    const blurb = results.posts[0].get("blurb");

    assert.ok(blurb.includes("thinking.png"));
    assert.ok(blurb.startsWith('<img width="20" height="20" src'));
    assert.ok(!blurb.includes(":thinking:"));
  });

  test("searchContextDescription", function (assert) {
    assert.strictEqual(
      searchContextDescription("topic"),
      I18n.t("search.context.topic")
    );
    assert.strictEqual(
      searchContextDescription("user", "silvio.dante"),
      I18n.t("search.context.user", { username: "silvio.dante" })
    );
    assert.strictEqual(
      searchContextDescription("category", "staff"),
      I18n.t("search.context.category", { category: "staff" })
    );
    assert.strictEqual(
      searchContextDescription("tag", "important"),
      I18n.t("search.context.tag", { tag: "important" })
    );
    assert.strictEqual(
      searchContextDescription("private_messages"),
      I18n.t("search.context.private_messages")
    );
    assert.strictEqual(searchContextDescription("bad_type"), undefined);
  });

  test("reciprocallyRankedList", async function (assert) {
    const sourceA = [
      {
        id: 250,
        name: "Bruce Wayne",
        username: "batman",
        topic: {
          id: 96,
          title: "I like to fight crime",
        },
      },
      {
        id: 202,
        name: "Peter Parker",
        username: "spidey",
        topic: {
          id: 32,
          title: "My experience meeting the Avengers",
        },
      },
      {
        id: 290,
        name: "Clark Kent",
        username: "superman",
        topic: {
          id: 111,
          title: "My fear of Kryptonite",
        },
      },
    ];

    const sourceB = [
      {
        id: 104,
        name: "Tony Stark",
        username: "ironman",
        topic: {
          id: 96,
          title: "What I learned from my father",
        },
      },
      {
        id: 246,
        name: "The Joker",
        username: "joker",
        topic: {
          id: 93,
          title: "Why don't you put a smile on that face...",
        },
      },
      {
        id: 245,
        name: "Loki",
        username: "loki",
        topic: {
          id: 92,
          title: "There is only one person you can trust",
        },
      },
    ];

    const desiredMixedResults = [
      {
        id: 250,
        name: "Bruce Wayne",
        reciprocalRank: 0.2,
        topic: {
          id: 96,
          title: "I like to fight crime",
        },
        username: "batman",
      },
      {
        id: 104,
        name: "Tony Stark",
        reciprocalRank: 0.2,
        topic: {
          id: 96,
          title: "What I learned from my father",
        },
        username: "ironman",
      },
      {
        id: 202,
        name: "Peter Parker",
        reciprocalRank: 0.16666666666666666,
        topic: {
          id: 32,
          title: "My experience meeting the Avengers",
        },
        username: "spidey",
      },
      {
        id: 246,
        name: "The Joker",
        reciprocalRank: 0.16666666666666666,
        topic: {
          id: 93,
          title: "Why don't you put a smile on that face...",
        },
        username: "joker",
      },
      {
        id: 290,
        name: "Clark Kent",
        reciprocalRank: 0.14285714285714285,
        topic: {
          id: 111,
          title: "My fear of Kryptonite",
        },
        username: "superman",
      },
      {
        id: 245,
        name: "Loki",
        reciprocalRank: 0.14285714285714285,
        topic: {
          id: 92,
          title: "There is only one person you can trust",
        },
        username: "loki",
      },
    ];

    const rankedList = reciprocallyRankedList([sourceA, sourceB]);

    assert.deepEqual(
      rankedList,
      desiredMixedResults,
      "it correctly ranks the results using the reciprocal ranking algorithm"
    );
  });
});
