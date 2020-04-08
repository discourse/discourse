import {
  translateResults,
  searchContextDescription
} from "discourse/lib/search";

QUnit.module("lib:search");

QUnit.test("unescapesEmojisInBlurbs", assert => {
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
        topic_id: 41
      }
    ],
    topics: [],
    users: [],
    categories: [],
    tags: [],
    groups: [],
    grouped_search_result: false
  };

  const results = translateResults(source);
  const blurb = results.posts[0].get("blurb");

  assert.ok(blurb.indexOf("thinking.png"));
  assert.ok(blurb.indexOf("<img src") === 0);
  assert.ok(blurb.indexOf(":thinking:") === -1);
});

QUnit.test("searchContextDescription", assert => {
  assert.equal(
    searchContextDescription("topic"),
    I18n.t("search.context.topic")
  );
  assert.equal(
    searchContextDescription("user", "silvio.dante"),
    I18n.t("search.context.user", { username: "silvio.dante" })
  );
  assert.equal(
    searchContextDescription("category", "staff"),
    I18n.t("search.context.category", { category: "staff" })
  );
  assert.equal(
    searchContextDescription("tag", "important"),
    I18n.t("search.context.tag", { tag: "important" })
  );
  assert.equal(
    searchContextDescription("private_messages"),
    I18n.t("search.context.private_messages")
  );
  assert.equal(searchContextDescription("bad_type"), null);
});
