import { module, test } from "qunit";
import {
  searchContextDescription,
  translateResults,
} from "discourse/lib/search";
import I18n from "I18n";

module("Unit | Utility | search", function () {
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
});
