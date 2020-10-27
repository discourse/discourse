import { exists } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  updateCurrentUser,
  acceptance,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Tags", function (needs) {
  needs.user();

  test("list the tags", async (assert) => {
    await visit("/tags");

    assert.ok($("body.tags-page").length, "has the body class");
    assert.ok(
      $('*[data-tag-name="eviltrout"]').length,
      "shows the eviltrout tag"
    );
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

  test("list the tags in groups", async (assert) => {
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
      $(".tag-list:first .discourse-tag")
        .toArray()
        .map((i) => {
          return $(i).text();
        }),
      ["focus", "Escort"],
      "shows the tags in default sort (by count)"
    );
    assert.deepEqual(
      $(".tag-list:first .discourse-tag")
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

  test("new topic button is not available for staff-only tags", async (assert) => {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/tag/regular-tag");
    assert.ok(find("#create-topic:disabled").length === 0);

    await visit("/tag/staff-only-tag");
    assert.ok(find("#create-topic:disabled").length === 1);

    updateCurrentUser({ moderator: true });

    await visit("/tag/regular-tag");
    assert.ok(find("#create-topic:disabled").length === 0);

    await visit("/tag/staff-only-tag");
    assert.ok(find("#create-topic:disabled").length === 0);
  });
});

acceptance("Tag info", function (needs) {
  needs.user();
  needs.settings({
    tags_listed_by_group: true,
  });
  needs.pretender((server, helper) => {
    server.get("/tag/planters/notifications", () => {
      return helper.response({
        tag_notification: { id: "planters", notification_level: 1 },
      });
    });

    server.get("/tag/planters/l/latest.json", () => {
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

    server.delete("/tag/planters/synonyms/containers", () =>
      helper.response({ success: true })
    );
  });

  test("tag info can show synonyms", async (assert) => {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/tag/planters");
    assert.ok(find("#show-tag-info").length === 1);

    await click("#show-tag-info");
    assert.ok(exists(".tag-info .tag-name"), "show tag");
    assert.ok(
      find(".tag-info .tag-associations").text().indexOf("Gardening") >= 0,
      "show tag group names"
    );
    assert.ok(
      find(".tag-info .synonyms-list .tag-box").length === 2,
      "shows the synonyms"
    );
    assert.ok(
      find(".tag-info .badge-category").length === 1,
      "show the category"
    );
    assert.ok(!exists("#rename-tag"), "can't rename tag");
    assert.ok(!exists("#edit-synonyms"), "can't edit synonyms");
    assert.ok(!exists("#delete-tag"), "can't delete tag");
  });

  test("admin can manage tags", async (assert) => {
    updateCurrentUser({ moderator: false, admin: true });

    await visit("/tag/planters");
    assert.ok(find("#show-tag-info").length === 1);

    await click("#show-tag-info");
    assert.ok(exists("#rename-tag"), "can rename tag");
    assert.ok(exists("#edit-synonyms"), "can edit synonyms");
    assert.ok(exists("#delete-tag"), "can delete tag");

    await click("#edit-synonyms");
    assert.ok(
      find(".unlink-synonym:visible").length === 2,
      "unlink UI is visible"
    );
    assert.ok(
      find(".delete-synonym:visible").length === 2,
      "delete UI is visible"
    );

    await click(".unlink-synonym:first");
    assert.ok(
      find(".tag-info .synonyms-list .tag-box").length === 1,
      "removed a synonym"
    );
  });
});
