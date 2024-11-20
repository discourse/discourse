import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import { i18n } from "discourse-i18n";

let deleteAndBlock = null;

acceptance("User Profile - Summary", function (needs) {
  needs.user();

  test("Viewing Summary", async function (assert) {
    await visit("/u/eviltrout/summary");

    assert.dom(".replies-section li a").exists("replies");
    assert.dom(".topics-section li a").exists("topics");
    assert.dom(".links-section li a").exists("links");
    assert.dom(".replied-section .user-info").exists("liked by");
    assert.dom(".liked-by-section .user-info").exists("liked by");
    assert.dom(".liked-section .user-info").exists("liked");
    assert.dom(".badges-section .badge-card").exists("badges");
    assert
      .dom(".top-categories-section .category-link")
      .exists("top categories");
  });

  test("Top Categories Search", async function (assert) {
    await visit("/u/eviltrout/summary");

    await click(".top-categories-section .reply-count a");
    assert.strictEqual(currentURL(), "/search?q=%40eviltrout%20%23bug");

    await visit("/u/eviltrout/summary");

    await click(".top-categories-section .topic-count a");
    assert.strictEqual(
      currentURL(),
      "/search?q=%40eviltrout%20%23bug%20in%3Afirst"
    );
  });
});

acceptance("User Profile - Summary - User Status", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/u/eviltrout.json", () => {
      const response = cloneJSON(userFixtures["/u/eviltrout.json"]);
      response.user.status = {
        description: "off to dentist",
        emoji: "tooth",
      };
      return helper.response(response);
    });
  });

  test("Shows User Status", async function (assert) {
    await visit("/u/eviltrout/summary");
    assert.dom(".user-status-message .emoji[alt='tooth']").exists();
  });
});

acceptance("User Profile - Summary - Stats", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/u/eviltrout/summary.json", () => {
      return helper.response(200, {
        user_summary: {
          likes_given: 1,
          likes_received: 2,
          topics_entered: 3,
          posts_read_count: 4,
          days_visited: 5,
          topic_count: 6,
          post_count: 7,
          time_read: 100000,
          recent_time_read: 1000,
          bookmark_count: 0,
          can_see_summary_stats: true,
          topic_ids: [1234],
          replies: [{ topic_id: 1234 }],
          links: [{ topic_id: 1234, url: "https://eviltrout.com" }],
          most_replied_to_users: [{ id: 333 }],
          most_liked_by_users: [{ id: 333 }],
          most_liked_users: [{ id: 333 }],
          badges: [{ badge_id: 444 }],
          top_categories: [
            {
              id: 1,
              name: "bug",
              color: "e9dd00",
              text_color: "000000",
              slug: "bug",
              read_restricted: false,
              parent_category_id: null,
              topic_count: 1,
              post_count: 1,
            },
          ],
        },
        badges: [{ id: 444, count: 1 }],
        topics: [{ id: 1234, title: "cool title", slug: "cool-title" }],
      });
    });
  });

  test("Summary Read Times", async function (assert) {
    await visit("/u/eviltrout/summary");

    assert.equal(query(".stats-time-read span").textContent.trim(), "1d");
    assert
      .dom(".stats-time-read span")
      .hasAttribute(
        "title",
        i18n("user.summary.time_read_title", { duration: "1 day" })
      );

    assert.equal(query(".stats-recent-read span").textContent.trim(), "17m");
    assert
      .dom(".stats-recent-read span")
      .hasAttribute(
        "title",
        i18n("user.summary.recent_time_read_title", { duration: "17 mins" })
      );
  });
});

acceptance("User Profile - Summary - Admin", function (needs) {
  needs.user({
    username: "eviltrout",
  });

  needs.pretender((server, helper) => {
    server.get("/admin/users/5.json", () => {
      return helper.response({
        id: 5,
        username: "charlie",
        name: null,
        avatar_template: "/letter_avatar_proxy/v4/letter/b/f0a364/{size}.png",
        active: true,
      });
    });
    server.delete("/admin/users/5.json", (request) => {
      const data = helper.parsePostData(request.requestBody);

      if (data.block_email || data.block_ip || data.block_urls) {
        deleteAndBlock = true;
      } else {
        deleteAndBlock = false;
      }

      return helper.response({});
    });
  });

  needs.hooks.beforeEach(() => {
    deleteAndBlock = null;
  });

  test("Delete only action", async function (assert) {
    await visit("/u/charlie/summary");
    await click(".btn-delete-user");
    await click(".dialog-footer .btn-primary");

    assert.notOk(deleteAndBlock, "first button does not block user");
  });

  test("Delete and block", async function (assert) {
    await visit("/u/charlie/summary");
    await click(".btn-delete-user");

    assert.equal(
      query("#dialog-title").textContent,
      i18n("admin.user.delete_confirm_title"),
      "dialog has a title"
    );

    await click(".dialog-footer .btn-danger");
    assert.ok(deleteAndBlock, "second button also block user");
  });
});
