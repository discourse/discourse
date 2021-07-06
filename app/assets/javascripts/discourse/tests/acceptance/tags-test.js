import {
  acceptance,
  count,
  exists,
  invisible,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Tags", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/tag/test/notifications", () =>
      helper.response({
        tag_notification: { id: "test", notification_level: 2 },
      })
    );

    server.get("/tag/test/l/unread.json", () =>
      helper.response({
        users: [
          {
            id: 42,
            username: "foo",
            name: "Foo",
            avatar_template: "/user_avatar/localhost/foo/{size}/10265_2.png",
          },
        ],
        primary_groups: [],
        topic_list: {
          can_create_topic: true,
          draft: null,
          draft_key: "new_topic",
          per_page: 30,
          top_tags: [],
          tags: [{ id: 42, name: "test", topic_count: 1, staff: false }],
          topics: [
            {
              id: 42,
              title: "Hello world",
              fancy_title: "Hello world",
              slug: "hello-world",
              posts_count: 1,
              reply_count: 1,
              highest_post_number: 1,
              created_at: "2020-01-01T00:00:00.000Z",
              last_posted_at: "2020-01-01T00:00:00.000Z",
              bumped: true,
              bumped_at: "2020-01-01T00:00:00.000Z",
              archetype: "regular",
              unseen: false,
              last_read_post_number: 1,
              unread_posts: 1,
              pinned: false,
              unpinned: null,
              visible: true,
              closed: true,
              archived: false,
              notification_level: 3,
              bookmarked: false,
              liked: true,
              tags: ["test"],
              views: 42,
              like_count: 42,
              has_summary: false,
              last_poster_username: "foo",
              pinned_globally: false,
              featured_link: null,
              posters: [],
            },
          ],
        },
      })
    );

    server.put("/topics/bulk", () => helper.response({}));

    server.get("/tags/c/faq/4/test/l/latest.json", () => {
      return helper.response({
        users: [],
        primary_groups: [],
        topic_list: {
          can_create_topic: true,
          draft: null,
          draft_key: "new_topic",
          draft_sequence: 1,
          per_page: 30,
          tags: [
            {
              id: 1,
              name: "planters",
              topic_count: 1,
            },
          ],
          topics: [],
        },
      });
    });
  });

  test("list the tags", async function (assert) {
    await visit("/tags");

    assert.ok($("body.tags-page").length, "has the body class");
    assert.ok(
      $('*[data-tag-name="eviltrout"]').length,
      "shows the eviltrout tag"
    );
  });

  test("dismiss notifications", async function (assert) {
    await visit("/tag/test/l/unread");
    await click("button.dismiss-read");
    await click(".dismiss-read-modal button.btn-primary");
    assert.ok(invisible(".dismiss-read-modal"));
  });

  test("hide tag notifications menu", async function (assert) {
    await visit("/tags/c/faq/4/test");
    assert.ok(invisible(".tag-notifications-button"));
  });
});

acceptance("Tags listed by group", function (needs) {
  needs.user();
  needs.settings({
    tags_listed_by_group: true,
  });
  needs.pretender((server, helper) => {
    server.get("/tag/regular-tag/notifications", () =>
      helper.response({
        tag_notification: { id: "regular-tag", notification_level: 1 },
      })
    );

    server.get("/tag/regular-tag/l/latest.json", () =>
      helper.response({
        users: [],
        primary_groups: [],
        topic_list: {
          can_create_topic: true,
          draft: null,
          draft_key: "new_topic",
          draft_sequence: 1,
          per_page: 30,
          tags: [
            {
              id: 1,
              name: "regular-tag",
              topic_count: 1,
            },
          ],
          topics: [],
        },
      })
    );

    server.get("/tag/staff-only-tag/notifications", () =>
      helper.response({
        tag_notification: { id: "staff-only-tag", notification_level: 1 },
      })
    );

    server.get("/tag/staff-only-tag/l/latest.json", () =>
      helper.response({
        users: [],
        primary_groups: [],
        topic_list: {
          can_create_topic: true,
          draft: null,
          draft_key: "new_topic",
          draft_sequence: 1,
          per_page: 30,
          tags: [
            {
              id: 1,
              name: "staff-only-tag",
              topic_count: 1,
              staff: true,
            },
          ],
          topics: [],
        },
      })
    );
  });

  test("list the tags in groups", async function (assert) {
    await visit("/tags");
    assert.equal(
      $(".tag-list").length,
      4,
      "shows separate lists for the 3 groups and the ungrouped tags"
    );
    assert.deepEqual(
      $(".tag-list h3")
        .toArray()
        .map((i) => {
          return $(i).text();
        }),
      ["Ford Cars", "Honda Cars", "Makes", "Other Tags"],
      "shown in given order and with tags that are not in a group"
    );
    assert.deepEqual(
      $(".tag-list:nth-of-type(1) .discourse-tag")
        .toArray()
        .map((i) => {
          return $(i).text();
        }),
      ["focus", "Escort"],
      "shows the tags in default sort (by count)"
    );
    assert.deepEqual(
      $(".tag-list:nth-of-type(1) .discourse-tag")
        .toArray()
        .map((i) => {
          return $(i).attr("href");
        }),
      ["/tag/focus", "/tag/escort"],
      "always uses lowercase URLs for mixed case tags"
    );
    assert.equal(
      $("a[data-tag-name='private']").attr("href"),
      "/u/eviltrout/messages/tags/private",
      "links to private messages"
    );
  });

  test("new topic button is not available for staff-only tags", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/tag/regular-tag");
    assert.ok(!exists("#create-topic:disabled"));

    await visit("/tag/staff-only-tag");
    assert.equal(count("#create-topic:disabled"), 1);

    updateCurrentUser({ moderator: true });

    await visit("/tag/regular-tag");
    assert.ok(!exists("#create-topic:disabled"));

    await visit("/tag/staff-only-tag");
    assert.ok(!exists("#create-topic:disabled"));
  });
});

acceptance("Tag info", function (needs) {
  needs.user();
  needs.settings({
    tags_listed_by_group: true,
  });
  needs.pretender((server, helper) => {
    server.get("/tag/:tag_name/notifications", (request) => {
      return helper.response({
        tag_notification: {
          id: request.params.tag_name,
          notification_level: 1,
        },
      });
    });

    server.get("/tag/:tag_name/l/latest.json", (request) => {
      return helper.response({
        users: [],
        primary_groups: [],
        topic_list: {
          can_create_topic: true,
          draft: null,
          draft_key: "new_topic",
          draft_sequence: 1,
          per_page: 30,
          tags: [
            {
              id: 1,
              name: request.params.tag_name,
              topic_count: 1,
            },
          ],
          topics: [],
        },
      });
    });

    server.get("/tags/c/faq/4/planters/l/latest.json", () => {
      return helper.response({
        users: [],
        primary_groups: [],
        topic_list: {
          can_create_topic: true,
          draft: null,
          draft_key: "new_topic",
          draft_sequence: 1,
          per_page: 30,
          tags: [
            {
              id: 1,
              name: "planters",
              topic_count: 1,
            },
          ],
          topics: [],
        },
      });
    });

    server.get("/tag/planters/info", () => {
      return helper.response({
        __rest_serializer: "1",
        tag_info: {
          id: 12,
          name: "planters",
          topic_count: 1,
          staff: false,
          synonyms: [
            {
              id: "containers",
              text: "containers",
            },
            {
              id: "planter",
              text: "planter",
            },
          ],
          tag_group_names: ["Gardening"],
          category_ids: [7],
        },
        categories: [
          {
            id: 7,
            name: "Outdoors",
            color: "000",
            text_color: "FFFFFF",
            slug: "outdoors",
            topic_count: 701,
            post_count: 5320,
            description: "Talk about the outdoors.",
            description_text: "Talk about the outdoors.",
            topic_url: "/t/category-definition-for-outdoors/1026",
            read_restricted: false,
            permission: null,
            notification_level: null,
          },
        ],
      });
    });

    server.get("/tag/happy-monkey/info", () => {
      return helper.response({
        __rest_serializer: "1",
        tag_info: {
          id: 13,
          name: "happy-monkey",
          topic_count: 1,
          staff: false,
          synonyms: [],
          tag_group_names: [],
          category_ids: [],
        },
        categories: [],
      });
    });

    server.delete("/tag/planters/synonyms/containers", () =>
      helper.response({ success: true })
    );

    server.get("/tags/filter/search", () =>
      helper.response({
        results: [
          { id: "monkey", text: "monkey", count: 1 },
          { id: "not-monkey", text: "not-monkey", count: 1 },
          { id: "happy-monkey", text: "happy-monkey", count: 1 },
        ],
      })
    );
  });

  test("tag info can show synonyms", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/tag/planters");
    assert.equal(count("#show-tag-info"), 1);

    await click("#show-tag-info");
    assert.ok(exists(".tag-info .tag-name"), "show tag");
    assert.ok(
      queryAll(".tag-info .tag-associations").text().indexOf("Gardening") >= 0,
      "show tag group names"
    );
    assert.equal(
      count(".tag-info .synonyms-list .tag-box"),
      2,
      "shows the synonyms"
    );
    assert.equal(count(".tag-info .badge-category"), 1, "show the category");
    assert.ok(!exists("#rename-tag"), "can't rename tag");
    assert.ok(!exists("#edit-synonyms"), "can't edit synonyms");
    assert.ok(!exists("#delete-tag"), "can't delete tag");
  });

  test("tag info hides only current tag in synonyms dropdown", async function (assert) {
    updateCurrentUser({ moderator: false, admin: true });

    await visit("/tag/happy-monkey");
    assert.equal(count("#show-tag-info"), 1);

    await click("#show-tag-info");
    assert.ok(exists(".tag-info .tag-name"), "show tag");

    await click("#edit-synonyms");
    await click("#add-synonyms .filter-input");

    assert.equal(count(".tag-chooser-row"), 2);
    assert.deepEqual(
      Array.from(find(".tag-chooser-row")).map((x) => x.dataset["value"]),
      ["monkey", "not-monkey"]
    );
  });

  test("can filter tags page by category", async function (assert) {
    await visit("/tag/planters");

    await click(".category-breadcrumb .category-drop-header");
    await click('.category-breadcrumb .category-row[data-name="faq"]');

    assert.equal(currentURL(), "/tags/c/faq/4/planters");
  });

  test("admin can manage tags", async function (assert) {
    updateCurrentUser({ moderator: false, admin: true });

    await visit("/tag/planters");
    assert.equal(count("#show-tag-info"), 1);

    await click("#show-tag-info");
    assert.ok(exists("#rename-tag"), "can rename tag");
    assert.ok(exists("#edit-synonyms"), "can edit synonyms");
    assert.ok(exists("#delete-tag"), "can delete tag");

    await click("#edit-synonyms");
    assert.ok(count(".unlink-synonym:visible"), 2, "unlink UI is visible");
    assert.equal(count(".delete-synonym:visible"), 2, "delete UI is visible");

    await click(".unlink-synonym:nth-of-type(1)");
    assert.equal(
      count(".tag-info .synonyms-list .tag-box"),
      1,
      "removed a synonym"
    );
  });

  test("composer will not set tags if user cannot create them", async function (assert) {
    await visit("/tag/planters");
    await click("#create-topic");
    let composer = this.owner.lookup("controller:composer");
    assert.equal(composer.get("model").tags, null);
  });
});
