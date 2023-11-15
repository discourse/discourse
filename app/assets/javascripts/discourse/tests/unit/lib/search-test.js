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
        topic_id: 96,
        topic: {
          id: 96,
          title: "I like to fight crime",
        },
      },
      {
        id: 104,
        name: "Steve Rogers",
        username: "captain_america",
        topic_id: 2,
        topic: {
          id: 2,
          title: "What its like being frozen...",
        },
      },
      {
        id: 202,
        name: "Peter Parker",
        username: "spidey",
        topic_id: 32,
        topic: {
          id: 32,
          title: "My experience meeting the Avengers",
        },
      },
      {
        id: 290,
        name: "Clark Kent",
        username: "superman",
        topic_id: 111,
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
        topic_id: 95,
        topic: {
          id: 95,
          title: "What I learned from my father",
        },
      },
      {
        id: 246,
        name: "The Joker",
        username: "joker",
        topic_id: 93,
        topic: {
          id: 93,
          title: "Why don't you put a smile on that face...",
        },
      },
      {
        id: 104,
        name: "Steve Rogers",
        username: "captain_america",
        topic_id: 2,
        topic: {
          id: 2,
          title: "What its like being frozen...",
        },
      },
      {
        id: 245,
        name: "Loki",
        username: "loki",
        topic_id: 92,
        topic: {
          id: 92,
          title: "There is only one person you can trust",
        },
      },
    ];

    const desiredMixedResults = [
      {
        id: 104,
        itemKey: "2_2",
        name: "Steve Rogers",
        reciprocalRank: 0.30952380952380953,
        topic: {
          id: 2,
          title: "What its like being frozen...",
        },
        topic_id: 2,
        username: "captain_america",
      },
      {
        id: 250,
        itemKey: "96_96",
        name: "Bruce Wayne",
        reciprocalRank: 0.2,
        topic: {
          id: 96,
          title: "I like to fight crime",
        },
        topic_id: 96,
        username: "batman",
      },
      {
        id: 104,
        itemKey: "95_95",
        name: "Tony Stark",
        reciprocalRank: 0.2,
        topic: {
          id: 95,
          title: "What I learned from my father",
        },
        topic_id: 95,
        username: "ironman",
      },
      {
        id: 246,
        itemKey: "93_93",
        name: "The Joker",
        reciprocalRank: 0.16666666666666666,
        topic: {
          id: 93,
          title: "Why don't you put a smile on that face...",
        },
        topic_id: 93,
        username: "joker",
      },
      {
        id: 202,
        itemKey: "32_32",
        name: "Peter Parker",
        reciprocalRank: 0.14285714285714285,
        topic: {
          id: 32,
          title: "My experience meeting the Avengers",
        },
        topic_id: 32,
        username: "spidey",
      },
      {
        id: 290,
        itemKey: "111_111",
        name: "Clark Kent",
        reciprocalRank: 0.125,
        topic: {
          id: 111,
          title: "My fear of Kryptonite",
        },
        topic_id: 111,
        username: "superman",
      },
      {
        id: 245,
        itemKey: "92_92",
        name: "Loki",
        reciprocalRank: 0.125,
        topic: {
          id: 92,
          title: "There is only one person you can trust",
        },
        topic_id: 92,
        username: "loki",
      },
    ];

    const rankedList = reciprocallyRankedList(
      [sourceA, sourceB],
      ["topic_id", "topic_id"]
    );

    assert.deepEqual(
      rankedList,
      desiredMixedResults,
      "it correctly ranks the results using the reciprocal ranking algorithm"
    );
  });

  test("reciprocallyRankedList (varied lists with more sources)", async function (assert) {
    const sourceA = [
      {
        id: 1,
        name: "Tony Stark",
        username: "ironman",
        topic_id: 21,
        topic: {
          id: 21,
          title: "I am iron man",
        },
      },
      {
        id: 2,
        name: "Steve Rogers",
        username: "captain_america",
        topic_id: 22,
        topic: {
          id: 22,
          title: "What its like being frozen...",
        },
      },
      {
        id: 3,
        name: "Peter Parker",
        username: "spidey",
        topic_id: 23,
        topic: {
          id: 23,
          title: "My experience meeting the Avengers",
        },
      },
      {
        id: 4,
        name: "Stephen Strange",
        username: "doctor_strange",
        topic_id: 24,
        topic: {
          id: 24,
          title: "14 mil different possible futures",
        },
      },
    ];

    const sourceB = [
      {
        id: 5,
        name: "Clark Kent",
        username: "superman",
        tid: 90,
        topic: {
          id: 90,
          title: "I am not from this planet.",
          fancy_title: "I am not from this planet.",
        },
      },
      {
        id: 6,
        name: "Bruce Wayne",
        username: "batman",
        tid: 91,
        topic: {
          id: 91,
          title: "It's not who I am underneath, but what I do that defines me.",
          fancy_title: "It's what I do that defines me.",
        },
      },
      {
        id: 7,
        name: "Steve Rogers",
        username: "captain_america",
        tid: 22,
        topic: {
          id: 22,
          title: "What its like being frozen...",
          fancy_title: "What its like being frozen...",
        },
      },
      {
        id: 8,
        name: "Barry Allen",
        username: "the_flash",
        tid: 93,
        topic: {
          id: 93,
          title: "Run Barry run!",
          fancy_title: "Run barry run!",
        },
      },
    ];

    const sourceC = [
      {
        id: 41,
        tuid: 906,
        name: "The Joker",
        username: "joker",
        user_id: 81,
        flair_name: "DC",
        topic: {
          title: "I am not from this planet.",
          can_edit: true,
        },
      },
      {
        id: 91,
        tuid: 23,
        name: "Peter Parker",
        username: "spidey",
        user_id: 80,
        flair_name: "Marvel",
        topic: {
          title: "My experience meeting the Avengers.",
          can_edit: false,
        },
      },
      {
        id: 42,
        tuid: 96,
        name: "Thanos",
        username: "thanos",
        user_id: 82,
        flair_name: "Marvel",
        topic: {
          title: "Fine, I'll do it myself",
          can_edit: true,
        },
      },
      {
        id: 43,
        tuid: 97,
        name: "Lex Luthor",
        username: "lex",
        user_id: 83,
        flair_name: "DC",
        topic: {
          title:
            "Devils don't come from the hell beneath us, they come from the sky",
          can_edit: true,
        },
      },
    ];

    const desiredMixedResults = [
      {
        id: 1,
        itemKey: "21__",
        name: "Tony Stark",
        reciprocalRank: 0.2,
        topic: {
          id: 21,
          title: "I am iron man",
        },
        topic_id: 21,
        username: "ironman",
      },
      {
        id: 5,
        itemKey: "_90_",
        name: "Clark Kent",
        reciprocalRank: 0.2,
        tid: 90,
        topic: {
          fancy_title: "I am not from this planet.",
          id: 90,
          title: "I am not from this planet.",
        },
        username: "superman",
      },
      {
        flair_name: "DC",
        id: 41,
        itemKey: "__906",
        name: "The Joker",
        reciprocalRank: 0.2,
        topic: {
          can_edit: true,
          title: "I am not from this planet.",
        },
        tuid: 906,
        user_id: 81,
        username: "joker",
      },
      {
        id: 2,
        itemKey: "22__",
        name: "Steve Rogers",
        reciprocalRank: 0.16666666666666666,
        topic: {
          id: 22,
          title: "What its like being frozen...",
        },
        topic_id: 22,
        username: "captain_america",
      },
      {
        id: 6,
        itemKey: "_91_",
        name: "Bruce Wayne",
        reciprocalRank: 0.16666666666666666,
        tid: 91,
        topic: {
          fancy_title: "It's what I do that defines me.",
          id: 91,
          title: "It's not who I am underneath, but what I do that defines me.",
        },
        username: "batman",
      },
      {
        flair_name: "Marvel",
        id: 91,
        itemKey: "__23",
        name: "Peter Parker",
        reciprocalRank: 0.16666666666666666,
        topic: {
          can_edit: false,
          title: "My experience meeting the Avengers.",
        },
        tuid: 23,
        user_id: 80,
        username: "spidey",
      },
      {
        id: 3,
        itemKey: "23__",
        name: "Peter Parker",
        reciprocalRank: 0.14285714285714285,
        topic: {
          id: 23,
          title: "My experience meeting the Avengers",
        },
        topic_id: 23,
        username: "spidey",
      },
      {
        id: 7,
        itemKey: "_22_",
        name: "Steve Rogers",
        reciprocalRank: 0.14285714285714285,
        tid: 22,
        topic: {
          fancy_title: "What its like being frozen...",
          id: 22,
          title: "What its like being frozen...",
        },
        username: "captain_america",
      },
      {
        flair_name: "Marvel",
        id: 42,
        itemKey: "__96",
        name: "Thanos",
        reciprocalRank: 0.14285714285714285,
        topic: {
          can_edit: true,
          title: "Fine, I'll do it myself",
        },
        tuid: 96,
        user_id: 82,
        username: "thanos",
      },
      {
        id: 4,
        itemKey: "24__",
        name: "Stephen Strange",
        reciprocalRank: 0.125,
        topic: {
          id: 24,
          title: "14 mil different possible futures",
        },
        topic_id: 24,
        username: "doctor_strange",
      },
      {
        id: 8,
        itemKey: "_93_",
        name: "Barry Allen",
        reciprocalRank: 0.125,
        tid: 93,
        topic: {
          fancy_title: "Run barry run!",
          id: 93,
          title: "Run Barry run!",
        },
        username: "the_flash",
      },
      {
        flair_name: "DC",
        id: 43,
        itemKey: "__97",
        name: "Lex Luthor",
        reciprocalRank: 0.125,
        topic: {
          can_edit: true,
          title:
            "Devils don't come from the hell beneath us, they come from the sky",
        },
        tuid: 97,
        user_id: 83,
        username: "lex",
      },
    ];

    const rankedList = reciprocallyRankedList(
      [sourceA, sourceB, sourceC],
      ["topic_id", "tid", "tuid"]
    );

    assert.deepEqual(
      rankedList,
      desiredMixedResults,
      "it correctly ranks the results using the reciprocal ranking algorithm"
    );
  });
});
