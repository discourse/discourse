import {
  acceptance,
  count,
  exists,
  queryAll,
  selectDate,
  visible,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  SEARCH_TYPE_CATS_TAGS,
  SEARCH_TYPE_DEFAULT,
  SEARCH_TYPE_USERS,
} from "discourse/controllers/full-page-search";
import selectKit from "discourse/tests/helpers/select-kit-helper";

let lastBody;

acceptance("Search - Full Page", function (needs) {
  needs.user();
  needs.settings({ tagging_enabled: true });
  needs.pretender((server, helper) => {
    server.get("/u/search/users", () => {
      return helper.response({
        users: [
          {
            username: "admin",
            name: "admin",
            avatar_template: "/images/avatar.png",
          },
        ],
      });
    });

    server.get("/admin/groups.json", () => {
      return helper.response({
        id: 2,
        automatic: true,
        name: "moderators",
        user_count: 4,
        alias_level: 0,
        visible: true,
        automatic_membership_email_domains: null,
        primary_group: false,
        title: null,
        grant_trust_level: null,
        incoming_email: null,
        notification_level: null,
        has_messages: true,
        is_member: true,
        mentionable: false,
        flair_url: null,
        flair_bg_color: null,
        flair_color: null,
      });
    });

    server.get("/badges.json", () => {
      return helper.response({
        badge_types: [{ id: 3, name: "Bronze", sort_order: 7 }],
        badge_groupings: [
          {
            id: 1,
            name: "Getting Started",
            description: null,
            position: 10,
            system: true,
          },
        ],
        badges: [
          {
            id: 17,
            name: "Reader",
            description:
              "Read every reply in a topic with more than 100 replies",
            grant_count: 0,
            allow_title: false,
            multiple_grant: false,
            icon: "fa-certificate",
            image: null,
            listable: true,
            enabled: true,
            badge_grouping_id: 1,
            system: true,
            long_description:
              "This badge is granted the first time you read a long topic with more than 100 replies. Reading a conversation closely helps you follow the discussion, understand different viewpoints, and leads to more interesting conversations. The more you read, the better the conversation gets. As we like to say, Reading is Fundamental! :slight_smile:\n",
            slug: "reader",
            has_badge: false,
            badge_type_id: 3,
          },
        ],
      });
    });

    server.put("/topics/bulk", (request) => {
      lastBody = helper.parsePostData(request.requestBody);
      return helper.response({ topic_ids: [7] });
    });
  });

  test("perform various searches", async function (assert) {
    await visit("/search");

    assert.ok($("body.search-page").length, "has body class");
    assert.ok(exists(".search-container"), "has container class");
    assert.ok(exists(".search-query"));
    assert.ok(!exists(".fps-topic"));

    await fillIn(".search-query", "none");
    await click(".search-cta");

    assert.ok(!exists(".fps-topic"), "has no results");
    assert.ok(exists(".no-results-suggestion"));
    assert.ok(exists(".google-search-form"));

    await fillIn(".search-query", "discourse");
    await click(".search-cta");

    assert.strictEqual(count(".fps-topic"), 1, "has one post");
  });

  test("search for personal messages", async function (assert) {
    await visit("/search");

    await fillIn(".search-query", "discourse in:personal");
    await click(".search-cta");

    assert.strictEqual(count(".fps-topic"), 1, "has one post");

    assert.strictEqual(
      count(".topic-status .personal_message"),
      1,
      "shows the right icon"
    );

    assert.strictEqual(count(".search-highlight"), 1, "search highlights work");
  });

  test("escape search term", async function (assert) {
    await visit("/search");
    await fillIn(".search-query", "@<script>prompt(1337)</script>gmail.com");

    assert.ok(
      exists(
        '.search-advanced-options span:contains("&lt;script&gt;prompt(1337)&lt;/script&gt;gmail.com")'
      ),
      "it escapes search term"
    );
  });

  test("update category through advanced search ui", async function (assert) {
    const categoryChooser = selectKit(
      ".search-advanced-options .category-chooser"
    );

    await visit("/search");

    await fillIn(".search-query", "none");

    await categoryChooser.expand();
    await categoryChooser.fillInFilter("faq");
    await categoryChooser.selectRowByValue(4);

    assert.ok(
      exists('.search-advanced-options .badge-category:contains("faq")'),
      'has "faq" populated'
    );
    assert.strictEqual(
      queryAll(".search-query").val(),
      "none #faq",
      'has updated search term to "none #faq"'
    );
  });

  test("update category without slug through advanced search ui", async function (assert) {
    const categoryChooser = selectKit(
      ".search-advanced-options .category-chooser"
    );

    await visit("/search");

    await fillIn(".search-query", "none");

    await categoryChooser.expand();
    await categoryChooser.fillInFilter("快乐的");
    await categoryChooser.selectRowByValue(240);

    assert.ok(
      exists('.search-advanced-options .badge-category:contains("快乐的")'),
      'has "快乐的" populated'
    );
    assert.strictEqual(
      queryAll(".search-query").val(),
      "none category:240",
      'has updated search term to "none category:240"'
    );
  });

  test("update in:title filter through advanced search ui", async function (assert) {
    await visit("/search");
    await fillIn(".search-query", "none");
    await click(".search-advanced-options .in-title");

    assert.ok(
      exists(".search-advanced-options .in-title:checked"),
      'has "in title" populated'
    );
    assert.strictEqual(
      queryAll(".search-query").val(),
      "none in:title",
      'has updated search term to "none in:title"'
    );

    await fillIn(".search-query", "none in:titleasd");

    assert.notOk(
      exists(".search-advanced-options .in-title:checked"),
      "does not populate title only checkbox"
    );
  });

  test("update in:likes filter through advanced search ui", async function (assert) {
    await visit("/search");
    await fillIn(".search-query", "none");
    await click(".search-advanced-options .in-likes");

    assert.ok(
      exists(".search-advanced-options .in-likes:checked"),
      'has "I liked" populated'
    );
    assert.strictEqual(
      queryAll(".search-query").val(),
      "none in:likes",
      'has updated search term to "none in:likes"'
    );
  });

  test("update in:personal filter through advanced search ui", async function (assert) {
    await visit("/search");
    await fillIn(".search-query", "none");
    await click(".search-advanced-options .in-private");

    assert.ok(
      exists(".search-advanced-options .in-private:checked"),
      'has "are in my messages" populated'
    );

    assert.strictEqual(
      queryAll(".search-query").val(),
      "none in:personal",
      'has updated search term to "none in:personal"'
    );

    await fillIn(".search-query", "none in:personal-direct");

    assert.notOk(
      exists(".search-advanced-options .in-private:checked"),
      "does not populate messages checkbox"
    );
  });

  test("update in:seen filter through advanced search ui", async function (assert) {
    await visit("/search");
    await fillIn(".search-query", "none");
    await click(".search-advanced-options .in-seen");

    assert.ok(
      exists(".search-advanced-options .in-seen:checked"),
      "it should check the right checkbox"
    );

    assert.strictEqual(
      queryAll(".search-query").val(),
      "none in:seen",
      "it should update the search term"
    );

    await fillIn(".search-query", "none in:seenasdan");

    assert.notOk(
      exists(".search-advanced-options .in-seen:checked"),
      "does not populate seen checkbox"
    );
  });

  test("update in filter through advanced search ui", async function (assert) {
    const inSelector = selectKit(".search-advanced-options .select-kit#in");

    await visit("/search");

    await fillIn(".search-query", "none");
    await inSelector.expand();
    await inSelector.selectRowByValue("bookmarks");

    assert.strictEqual(
      inSelector.header().label(),
      "I bookmarked",
      'has "I bookmarked" populated'
    );
    assert.strictEqual(
      queryAll(".search-query").val(),
      "none in:bookmarks",
      'has updated search term to "none in:bookmarks"'
    );
  });

  test("update status through advanced search ui", async function (assert) {
    const statusSelector = selectKit(
      ".search-advanced-options .select-kit#search-status-options"
    );

    await visit("/search");

    await fillIn(".search-query", "none");
    await statusSelector.expand();
    await statusSelector.selectRowByValue("closed");

    assert.strictEqual(
      statusSelector.header().label(),
      "are closed",
      'has "are closed" populated'
    );
    assert.strictEqual(
      queryAll(".search-query").val(),
      "none status:closed",
      'has updated search term to "none status:closed"'
    );
  });

  test("doesn't update status filter header if wrong value entered through searchbox", async function (assert) {
    const statusSelector = selectKit(
      ".search-advanced-options .select-kit#search-status-options"
    );

    await visit("/search");

    await fillIn(".search-query", "status:none");

    assert.strictEqual(
      statusSelector.header().label(),
      "any",
      'has "any" populated'
    );
  });

  test("doesn't update in filter header if wrong value entered through searchbox", async function (assert) {
    const inSelector = selectKit(".search-advanced-options .select-kit#in");

    await visit("/search");

    await fillIn(".search-query", "in:none");

    assert.strictEqual(
      inSelector.header().label(),
      "any",
      'has "any" populated'
    );
  });

  test("update post time through advanced search ui", async function (assert) {
    await visit("/search?expanded=true&q=after:2018-08-22");

    assert.strictEqual(
      queryAll(".search-query").val(),
      "after:2018-08-22",
      "it should update the search term correctly"
    );

    await visit("/search");

    await fillIn(".search-query", "none");
    await selectDate(".date-picker#search-post-date", "2016-10-05");

    const postTimeSelector = selectKit(
      ".search-advanced-options .select-kit#postTime"
    );
    await postTimeSelector.expand();
    await postTimeSelector.selectRowByValue("after");

    assert.strictEqual(
      postTimeSelector.header().label(),
      "after",
      'has "after" populated'
    );

    assert.strictEqual(
      queryAll(".search-query").val(),
      "none after:2016-10-05",
      'has updated search term to "none after:2016-10-05"'
    );
  });

  test("update min post count through advanced search ui", async function (assert) {
    await visit("/search");
    await fillIn(".search-query", "none");
    await fillIn("#search-min-post-count", "5");

    assert.strictEqual(
      queryAll(
        ".search-advanced-additional-options #search-min-post-count"
      ).val(),
      "5",
      'has "5" populated'
    );
    assert.strictEqual(
      queryAll(".search-query").val(),
      "none min_posts:5",
      'has updated search term to "none min_posts:5"'
    );
  });

  test("update max post count through advanced search ui", async function (assert) {
    await visit("/search");
    await fillIn(".search-query", "none");
    await fillIn("#search-max-post-count", "5");

    assert.strictEqual(
      queryAll(
        ".search-advanced-additional-options #search-max-post-count"
      ).val(),
      "5",
      'has "5" populated'
    );
    assert.strictEqual(
      queryAll(".search-query").val(),
      "none max_posts:5",
      'has updated search term to "none max_posts:5"'
    );
  });

  test("validate advanced search when initially empty", async function (assert) {
    await visit("/search?expanded=true");
    await click(".search-advanced-options .in-likes");

    assert.ok(
      selectKit(".search-advanced-options .in-likes:checked"),
      'has "I liked" populated'
    );

    assert.strictEqual(
      queryAll(".search-query").val(),
      "in:likes",
      'has updated search term to "in:likes"'
    );

    await fillIn(".search-query", "in:likesasdas");

    assert.notOk(
      exists(".search-advanced-options .in-likes:checked"),
      "does not populate the likes checkbox"
    );
  });

  test("all tags checkbox only visible for two or more tags", async function (assert) {
    await visit("/search?expanded=true");

    const tagSelector = selectKit("#search-with-tags");

    await tagSelector.expand();
    await tagSelector.selectRowByValue("monkey");

    assert.ok(!visible("input.all-tags"), "all tags checkbox not visible");

    await tagSelector.selectRowByValue("gazelle");
    assert.ok(visible("input.all-tags"), "all tags checkbox is visible");
  });

  test("search for users", async function (assert) {
    await visit("/search");

    const typeSelector = selectKit(".search-bar .select-kit#search-type");

    await fillIn(".search-query", "admin");
    assert.ok(!exists(".fps-user-item"), "has no user results");

    await typeSelector.expand();
    await typeSelector.selectRowByValue(SEARCH_TYPE_USERS);

    assert.ok(!exists(".search-filters"), "has no filters");

    await click(".search-cta");

    assert.strictEqual(count(".fps-user-item"), 1, "has one user result");

    await typeSelector.expand();
    await typeSelector.selectRowByValue(SEARCH_TYPE_DEFAULT);

    assert.ok(
      exists(".search-filters"),
      "returning to topic/posts shows filters"
    );
    assert.ok(!exists(".fps-user-item"), "has no user results");
  });

  test("search for categories/tags", async function (assert) {
    await visit("/search");

    await fillIn(".search-query", "none");
    const typeSelector = selectKit(".search-bar .select-kit#search-type");

    assert.ok(!exists(".fps-tag-item"), "has no category/tag results");

    await typeSelector.expand();
    await typeSelector.selectRowByValue(SEARCH_TYPE_CATS_TAGS);
    await click(".search-cta");

    assert.ok(!exists(".search-filters"), "has no filters");
    assert.strictEqual(count(".fps-tag-item"), 2, "has two tag results");

    await typeSelector.expand();
    await typeSelector.selectRowByValue(SEARCH_TYPE_DEFAULT);

    assert.ok(
      exists(".search-filters"),
      "returning to topic/posts shows filters"
    );
    assert.ok(!exists(".fps-tag-item"), "has no tag results");
  });

  test("filters expand/collapse as expected", async function (assert) {
    await visit("/search?expanded=true");

    assert.ok(
      visible(".search-advanced-options"),
      "advanced filters are expanded when url query param is included"
    );

    await fillIn(".search-query", "none");
    await click(".search-cta");

    assert.notOk(
      exists(".advanced-filters[open]"),
      "launching a search collapses advanced filters"
    );

    await visit("/search");

    assert.notOk(
      exists(".advanced-filters[open]"),
      "filters are collapsed when query param is not present"
    );

    await click(".advanced-filters > summary");
    assert.ok(
      visible(".search-advanced-options"),
      "clicking on element expands filters"
    );
  });

  test("bulk operations work", async function (assert) {
    await visit("/search");
    await fillIn(".search-query", "discourse");
    await click(".search-cta");
    await click(".bulk-select"); // toggle bulk
    await click(".bulk-select-visible .btn:nth-child(2)"); // select all
    await click(".bulk-select-btn"); // show bulk actions
    await click(".topic-bulk-actions-modal .btn:nth-child(2)"); // close topics
    assert.equal(lastBody["topic_ids[]"], 7);
  });
});
