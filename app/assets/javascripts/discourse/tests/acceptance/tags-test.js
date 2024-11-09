import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  count,
  query,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "discourse-i18n";

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
              tags_descriptions: { test: "test description" },
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

    assert.ok(
      document.body.classList.contains("tags-page"),
      "has the body class"
    );
    assert.dom(`[data-tag-name="eviltrout"]`).exists("shows the eviltrout tag");
  });

  test("dismiss notifications", async function (assert) {
    await visit("/tag/test/l/unread");
    await click("button.dismiss-read");
    await click(".dismiss-read-modal button.btn-primary");
    assert.dom(".dismiss-read-modal").doesNotExist();
  });

  test("hide tag notifications menu", async function (assert) {
    await visit("/tags/c/faq/4/test");
    assert.dom(".tag-notifications-button").doesNotExist();
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

    assert.strictEqual(
      count(".tag-list"),
      4,
      "shows separate lists for the 3 groups and the ungrouped tags"
    );
    assert.deepEqual(
      [...queryAll(".tag-list h3")].map((el) => el.innerText),
      ["Ford Cars", "Honda Cars", "Makes", "Other Tags"],
      "shown in given order and with tags that are not in a group"
    );
    assert.deepEqual(
      [...queryAll(".tag-list:nth-of-type(1) .discourse-tag")].map(
        (el) => el.innerText
      ),
      ["focus", "Escort"],
      "shows the tags in default sort (by count)"
    );

    assert
      .dom(".tag-list .tag-box:nth-of-type(1) .discourse-tag")
      .hasAttribute("href", "/tag/focus");
    assert
      .dom(".tag-list .tag-box:nth-of-type(2) .discourse-tag")
      .hasAttribute(
        "href",
        "/tag/escort",
        "uses a lowercase URL for a mixed case tag"
      );

    assert
      .dom(`a[data-tag-name="private"]`)
      .hasAttribute(
        "href",
        "/u/eviltrout/messages/tags/private",
        "links to private messages"
      );
  });

  test("new topic button is not available for staff-only tags", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/tag/regular-tag");
    assert.dom("#create-topic:disabled").doesNotExist();

    await visit("/tag/staff-only-tag");
    assert.strictEqual(count("#create-topic:disabled"), 1);

    updateCurrentUser({ moderator: true });

    await visit("/tag/regular-tag");
    assert.dom("#create-topic:disabled").doesNotExist();

    await visit("/tag/staff-only-tag");
    assert.dom("#create-topic:disabled").doesNotExist();
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

    [
      "/tags/c/faq/4/planters/l/latest.json",
      "/tags/c/feature/2/planters/l/latest.json",
      "/tags/c/feature/2/planters/l/hot.json",
      "/tags/c/feature/2/none/planters/l/latest.json",
    ].forEach((url) => {
      server.get(url, () => {
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

    server.get("/tags/c/feature/2/none/l/latest.json", () => {
      return helper.response({
        users: [],
        primary_groups: [],
        topic_list: {
          can_create_topic: true,
          draft: null,
          draft_key: "new_topic",
          draft_sequence: 1,
          per_page: 30,
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
    server.put("/tag/happy-monkey", (request) => {
      const data = helper.parsePostData(request.requestBody);
      return helper.response({ tag: { id: data.tag.id } });
    });

    server.get("/tag/happy-monkey/info", () => {
      return helper.response({
        __rest_serializer: "1",
        tag_info: {
          id: 13,
          name: "happy-monkey",
          description: "happy monkey description",
          topic_count: 1,
          staff: false,
          synonyms: [],
          tag_group_names: [],
          category_ids: [],
        },
        categories: [],
      });
    });

    server.get("/tag/happy-monkey2/info", () => {
      return helper.response({
        __rest_serializer: "1",
        tag_info: {
          id: 13,
          name: "happy-monkey2",
          description: "happy monkey description",
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
          { id: "monkey", name: "monkey", count: 1 },
          { id: "not-monkey", name: "not-monkey", count: 1 },
          { id: "happy-monkey", name: "happy-monkey", count: 1 },
        ],
      })
    );
  });

  test("tag info can show synonyms", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/tag/planters");
    assert.strictEqual(count("#show-tag-info"), 1);

    await click("#show-tag-info");
    assert.dom(".tag-info .tag-name").exists("show tag");
    assert.ok(
      query(".tag-info .tag-associations").innerText.includes("Gardening"),
      "show tag group names"
    );
    assert.strictEqual(
      count(".tag-info .synonyms-list .tag-box"),
      2,
      "shows the synonyms"
    );
    assert.strictEqual(
      count(".tag-info .badge-category"),
      1,
      "show the category"
    );
    assert.dom("#rename-tag").doesNotExist("can't rename tag");
    assert.dom("#edit-synonyms").doesNotExist("can't edit synonyms");
    assert.dom("#delete-tag").doesNotExist("can't delete tag");
  });

  test("tag info hides only current tag in synonyms dropdown", async function (assert) {
    updateCurrentUser({ moderator: false, admin: true });

    await visit("/tag/happy-monkey");
    assert.strictEqual(count("#show-tag-info"), 1);

    await click("#show-tag-info");
    assert.dom(".tag-info .tag-name").exists("show tag");

    await click("#edit-synonyms");

    const addSynonymsDropdown = selectKit("#add-synonyms");
    await addSynonymsDropdown.expand();

    assert.deepEqual(
      Array.from(addSynonymsDropdown.rows()).map((r) => {
        return r.dataset.value;
      }),
      ["monkey", "not-monkey"]
    );
  });

  test("edit tag is showing input for name and description", async function (assert) {
    updateCurrentUser({ moderator: false, admin: true });

    await visit("/tag/happy-monkey");
    assert.strictEqual(count("#show-tag-info"), 1);

    await click("#show-tag-info");
    assert.dom(".tag-info .tag-name").exists("show tag");

    await click(".edit-tag");
    assert.strictEqual(
      query("#edit-name").value,
      "happy-monkey",
      "it displays original tag name"
    );
    assert.strictEqual(
      query("#edit-description").value,
      "happy monkey description",
      "it displays original tag description"
    );

    await fillIn("#edit-description", "new description");
    await click(".submit-edit");
    assert.strictEqual(
      currentURL(),
      "/tag/happy-monkey",
      "it doesn't change URL"
    );

    await click(".edit-tag");
    await fillIn("#edit-name", "happy-monkey2");
    await click(".submit-edit");
    assert.strictEqual(
      currentURL(),
      "/tag/happy-monkey2",
      "it changes URL to new tag path"
    );
  });

  test("tag info hides when tag filter removed", async function (assert) {
    await visit("/tag/happy-monkey");

    await click("#show-tag-info");
    assert.dom(".tag-info .tag-name").exists();

    await visit("/latest");

    assert.dom(".tag-info").doesNotExist("tag info is not shown on homepage");
  });

  test("can filter tags page by category", async function (assert) {
    await visit("/tag/planters");

    await click(".category-breadcrumb .category-drop-header");
    await click(`.category-breadcrumb .category-row[data-name="faq"]`);

    assert.strictEqual(currentURL(), "/tags/c/faq/4/planters");
  });

  test("can switch between all/none subcategories", async function (assert) {
    await visit("/tag/planters");

    await click(".category-breadcrumb .category-drop-header");
    await click(`.category-breadcrumb .category-row[data-name="feature"]`);
    assert.strictEqual(currentURL(), "/tags/c/feature/2/planters");

    await click(".category-breadcrumb li:nth-of-type(2) .category-drop-header");
    await click(
      `.category-breadcrumb li:nth-of-type(2) .category-row[data-value="no-categories"]`
    );
    assert.strictEqual(currentURL(), "/tags/c/feature/2/none/planters");
  });

  test("sets document title correctly", async function (assert) {
    await visit("/tag/planters");
    assert.strictEqual(
      document.title,
      I18n.t("tagging.filters.without_category", {
        filter: "Latest",
        tag: "planters",
      }) + ` - ${this.siteSettings.title}`
    );

    await click(".category-breadcrumb .category-drop-header");
    await click(`.category-breadcrumb .category-row[data-name="feature"]`);
    assert.strictEqual(currentURL(), "/tags/c/feature/2/planters");
    assert.strictEqual(
      document.title,
      I18n.t("tagging.filters.with_category", {
        filter: "Latest",
        tag: "planters",
        category: "feature",
      }) + ` - ${this.siteSettings.title}`
    );

    await click(".tag-drop-header");
    await click(`.tag-row[data-value="no-tags"]`);
    assert.strictEqual(currentURL(), "/tags/c/feature/2/none");
    assert.strictEqual(
      document.title,
      I18n.t("tagging.filters.untagged_with_category", {
        filter: "Latest",
        category: "feature",
      }) + ` - ${this.siteSettings.title}`
    );
  });

  test("can visit show-category-latest routes", async function (assert) {
    await visit("/tags/c/feature/2/planters");

    await click(".nav-item_latest a[href]");
    assert.strictEqual(currentURL(), "/tags/c/feature/2/planters/l/latest");

    await click(".nav-item_hot a[href]");
    assert.strictEqual(currentURL(), "/tags/c/feature/2/planters/l/hot");
  });

  test("admin can manage tags", async function (assert) {
    updateCurrentUser({ moderator: false, admin: true });

    await visit("/tag/planters");
    assert.strictEqual(count("#show-tag-info"), 1);

    await click("#show-tag-info");
    assert.dom(".edit-tag").exists("can rename tag");
    assert.dom("#edit-synonyms").exists("can edit synonyms");
    assert.dom("#delete-tag").exists("can delete tag");

    await click("#edit-synonyms");
    assert.strictEqual(
      count(".unlink-synonym:visible"),
      2,
      "unlink UI is visible"
    );
    assert.strictEqual(
      count(".delete-synonym:visible"),
      2,
      "delete UI is visible"
    );

    await click(".unlink-synonym:nth-of-type(1)");
    assert.strictEqual(
      count(".tag-info .synonyms-list .tag-box"),
      1,
      "removed a synonym"
    );
  });

  test("composer will not set tags if user cannot create them", async function (assert) {
    await visit("/tag/planters");
    await click("#create-topic");
    let composer = this.owner.lookup("service:composer");
    assert.deepEqual(composer.get("model").tags, []);
  });
});

acceptance(
  "Tag show - topic list with `more_topics_url` present",
  function (needs) {
    needs.pretender((server, helper) => {
      server.get("/tag/:tagName/l/latest.json", () =>
        helper.response({
          users: [],
          primary_groups: [],
          topic_list: {
            topics: [],
            more_topics_url: "...",
          },
        })
      );
      server.put("/topics/bulk", () => helper.response({}));
    });

    test("load more footer message is present", async function (assert) {
      await visit("/tag/planters");
      assert.dom(".topic-list-bottom .footer-message").doesNotExist();
    });
  }
);

acceptance("Tag show - create topic", function (needs) {
  needs.user();
  needs.site({ can_tag_topics: true });
  needs.settings({
    tagging_enabled: true,
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
  });

  test("composer will not set tags with all/none tags when creating topic", async function (assert) {
    const composer = this.owner.lookup("service:composer");

    await visit("/tag/none");
    await click("#create-topic");
    assert.deepEqual(composer.model.tags, []);

    await visit("/tag/all");
    await click("#create-topic");
    assert.deepEqual(composer.model.tags, []);
  });

  test("composer will set tags from selected tag", async function (assert) {
    const composer = this.owner.lookup("service:composer");

    await visit("/tag/planters");
    await click("#create-topic");
    assert.deepEqual(composer.model.tags, ["planters"]);
  });
});

acceptance("Tag show - topic list without `more_topics_url`", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/tag/:tagName/l/latest.json", () =>
      helper.response({
        users: [],
        primary_groups: [],
        topic_list: {
          topics: [],
        },
      })
    );
    server.put("/topics/bulk", () => helper.response({}));
  });
  test("load more footer message is not present", async function (assert) {
    await visit("/tag/planters");
    assert.dom(".topic-list-bottom .footer-message").exists();
  });
});
