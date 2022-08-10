import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { render } from "@ember/test-helpers";
import { deepMerge } from "discourse-common/lib/object";
import { hbs } from "ember-cli-htmlbars";

function getBookmark(overrides = {}) {
  return deepMerge(
    {
      id: 6,
      created_at: "2022-08-05T06:09:39.559Z",
      updated_at: "2022-08-05T06:11:27.246Z",
      name: "",
      reminder_at: "2022-08-05T06:10:42.223Z",
      reminder_at_ics_start: "20220805T061042Z",
      reminder_at_ics_end: "20220805T071042Z",
      pinned: false,
      title: "Test poll topic hello world",
      fancy_title: "Test poll topic hello world",
      excerpt: "poll",
      bookmarkable_id: 1009,
      bookmarkable_type: "Post",
      bookmarkable_url: "http://localhost:4200/t/this-bookmarkable-url/227/1",
      tags: [],
      tags_descriptions: {},
      truncated: true,
      topic_id: 227,
      linked_post_number: 1,
      deleted: false,
      hidden: false,
      category_id: 1,
      closed: false,
      archived: false,
      archetype: "regular",
      highest_post_number: 45,
      last_read_post_number: 31,
      bumped_at: "2022-04-21T15:14:37.359Z",
      slug: "test-poll-topic-hello-world",
      user: {
        id: 1,
        username: "somebody",
        name: "Mr. Somebody",
        avatar_template: "/letter_avatar_proxy/v4/letter/o/f05b48/{size}.png",
      },
    },
    overrides
  );
}

module("Integration | Component | user-menu | bookmark-item", function (hooks) {
  setupRenderingTest(hooks);

  const template = hbs`<UserMenu::BookmarkItem @item={{this.bookmark}}/>`;

  test("uses bookmarkable_url for the href", async function (assert) {
    this.set("bookmark", getBookmark());
    await render(template);
    assert.ok(
      query("li.bookmark a").href.endsWith("/t/this-bookmarkable-url/227/1")
    );
  });

  test("item label is the bookmarked post author", async function (assert) {
    this.set(
      "bookmark",
      getBookmark({ user: { username: "bookmarkPostAuthor" } })
    );
    await render(template);
    assert.strictEqual(
      query("li.bookmark .item-label").textContent.trim(),
      "bookmarkPostAuthor"
    );
  });

  test("item description is the bookmark title", async function (assert) {
    this.set("bookmark", getBookmark({ title: "Custom bookmark title" }));
    await render(template);
    assert.strictEqual(
      query("li.bookmark .item-description").textContent.trim(),
      "Custom bookmark title"
    );
  });
});
