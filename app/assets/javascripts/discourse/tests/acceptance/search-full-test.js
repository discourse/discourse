import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  SEARCH_TYPE_CATS_TAGS,
  SEARCH_TYPE_DEFAULT,
  SEARCH_TYPE_USERS,
} from "discourse/controllers/full-page-search";
import { acceptance, selectDate } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

let searchResultClickTracked = false;

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
            icon: "certificate",
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

    server.post("/search/click", () => {
      searchResultClickTracked = true;
      return helper.response({ success: "OK" });
    });
  });

  needs.hooks.afterEach(() => {
    searchResultClickTracked = false;
  });

  test("perform various searches", async function (assert) {
    await visit("/search");

    assert.dom(document.body).hasClass("search-page", "has body class");
    assert.dom(".search-container").exists("has container class");
    assert.dom(".search-query").exists();
    assert.dom(".fps-topic").doesNotExist();

    await fillIn(".search-query", "none");
    await click(".search-cta");

    assert.dom(".fps-topic").doesNotExist("has no results");
    assert.dom(".no-results-suggestion").exists();
    assert.dom(".google-search-form").exists();

    await fillIn(".search-query", "discourse");
    await click(".search-cta");

    assert.dom(".fps-topic").exists({ count: 1 }, "has one post");
  });

  test("search for personal messages", async function (assert) {
    await visit("/search");

    await fillIn(".search-query", "discourse in:messages");
    await click(".search-cta");

    assert.dom(".fps-topic").exists({ count: 1 }, "has one post");

    assert
      .dom(".topic-status .personal_message")
      .exists({ count: 1 }, "shows the right icon");

    assert
      .dom(".search-highlight")
      .exists({ count: 1 }, "search highlights work");
  });

  test("escape search term", async function (assert) {
    await visit("/search");
    await fillIn(".search-query", "@<script>prompt(1337)</script>gmail.com");

    await click(".advanced-filters > summary");

    assert.strictEqual(
      selectKit("#search-posted-by").header().label(),
      "&lt;script&gt;prompt(1337)&lt;/script&gt;gmail.com"
    );
  });

  test("update category through advanced search UI", async function (assert) {
    const categoryChooser = selectKit(
      ".search-advanced-options .category-chooser"
    );

    await visit("/search");

    await fillIn(".search-query", "none");

    await categoryChooser.expand();
    await categoryChooser.fillInFilter("faq");
    await categoryChooser.selectRowByValue(4);

    await click(".advanced-filters > summary");
    assert.strictEqual(
      selectKit("#search-in-category").header().label(),
      "faq"
    );

    assert
      .dom(".search-query")
      .hasValue("none #faq", 'has updated search term to "none #faq"');
  });

  test("update category without slug through advanced search UI", async function (assert) {
    const categoryChooser = selectKit(
      ".search-advanced-options .category-chooser"
    );

    await visit("/search");

    await fillIn(".search-query", "none");

    await categoryChooser.expand();
    await categoryChooser.fillInFilter("快乐的");
    await categoryChooser.selectRowByValue(240);

    await click(".advanced-filters > summary");
    assert.strictEqual(
      selectKit("#search-in-category").header().label(),
      "快乐的"
    );

    assert
      .dom(".search-query")
      .hasValue(
        "none category:240",
        'has updated search term to "none category:240"'
      );
  });

  test("update in:title filter through advanced search UI", async function (assert) {
    await visit("/search");
    await fillIn(".search-query", "none");
    await click(".search-advanced-options .in-title");

    assert
      .dom(".search-advanced-options .in-title")
      .isChecked('has "in title" populated');
    assert
      .dom(".search-query")
      .hasValue("none in:title", 'has updated search term to "none in:title"');

    await fillIn(".search-query", "none in:titleasd");

    assert
      .dom(".search-advanced-options .in-title")
      .isNotChecked("does not populate title only checkbox");
  });

  test("update in:likes filter through advanced search UI", async function (assert) {
    await visit("/search");
    await fillIn(".search-query", "none");
    await click(".search-advanced-options .in-likes");

    assert
      .dom(".search-advanced-options .in-likes")
      .isChecked('has "I liked" populated');
    assert
      .dom(".search-query")
      .hasValue("none in:likes", 'has updated search term to "none in:likes"');
  });

  test("update in:messages filter through advanced search UI", async function (assert) {
    await visit("/search");
    await fillIn(".search-query", "none");
    await click(".search-advanced-options .in-private");

    assert
      .dom(".search-advanced-options .in-private")
      .isChecked('has "are in my messages" populated');

    assert
      .dom(".search-query")
      .hasValue(
        "none in:messages",
        'has updated search term to "none in:messages"'
      );

    await fillIn(".search-query", "none in:personal-direct");

    assert
      .dom(".search-advanced-options .in-private")
      .isNotChecked("does not populate messages checkbox");
  });

  test("update in:seen filter through advanced search UI", async function (assert) {
    await visit("/search");
    await fillIn(".search-query", "none");
    await click(".search-advanced-options .in-seen");

    assert
      .dom(".search-advanced-options .in-seen")
      .isChecked("it should check the right checkbox");

    assert
      .dom(".search-query")
      .hasValue("none in:seen", "it should update the search term");

    await fillIn(".search-query", "none in:seenasdan");

    assert
      .dom(".search-advanced-options .in-seen")
      .isNotChecked("does not populate seen checkbox");
  });

  test("update in filter through advanced search UI", async function (assert) {
    const inSelector = selectKit(".search-advanced-options .select-kit#in");

    await visit("/search");

    await click(".advanced-filters > summary");
    await fillIn(".search-query", "none");
    await inSelector.expand();
    await inSelector.selectRowByValue("bookmarks");

    assert.strictEqual(
      inSelector.header().label(),
      "I bookmarked",
      'has "I bookmarked" populated'
    );
    assert
      .dom(".search-query")
      .hasValue(
        "none in:bookmarks",
        'has updated search term to "none in:bookmarks"'
      );
  });

  test("update status through advanced search UI", async function (assert) {
    const statusSelector = selectKit(
      ".search-advanced-options .select-kit#search-status-options"
    );

    await visit("/search");

    await click(".advanced-filters > summary");
    await fillIn(".search-query", "none");
    await statusSelector.expand();
    await statusSelector.selectRowByValue("closed");

    assert.strictEqual(
      statusSelector.header().label(),
      "are closed",
      'has "are closed" populated'
    );
    assert
      .dom(".search-query")
      .hasValue(
        "none status:closed",
        'has updated search term to "none status:closed"'
      );
  });

  test("doesn't update status filter header if wrong value entered through searchbox", async function (assert) {
    const statusSelector = selectKit(
      ".search-advanced-options .select-kit#search-status-options"
    );

    await visit("/search");

    await click(".advanced-filters > summary");
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

    await click(".advanced-filters > summary");
    await fillIn(".search-query", "in:none");

    assert.strictEqual(
      inSelector.header().label(),
      "any",
      'has "any" populated'
    );
  });

  test("update post time through advanced search UI", async function (assert) {
    await visit("/search?expanded=true&q=after:2018-08-22");

    assert
      .dom(".search-query")
      .hasValue(
        "after:2018-08-22",
        "it should update the search term correctly"
      );

    await visit("/search");
    await click(".advanced-filters > summary");

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

    assert
      .dom(".search-query")
      .hasValue(
        "none after:2016-10-05",
        'has updated search term to "none after:2016-10-05"'
      );
  });

  test("update min post count through advanced search UI", async function (assert) {
    await visit("/search");
    await click(".advanced-filters > summary");
    await fillIn(".search-query", "none");
    await fillIn("#search-min-post-count", "5");

    assert
      .dom(".search-advanced-additional-options #search-min-post-count")
      .hasValue("5", 'has "5" populated');
    assert
      .dom(".search-query")
      .hasValue(
        "none min_posts:5",
        'has updated search term to "none min_posts:5"'
      );
  });

  test("update max post count through advanced search UI", async function (assert) {
    await visit("/search");
    await click(".advanced-filters > summary");
    await fillIn(".search-query", "none");
    await fillIn("#search-max-post-count", "5");

    assert
      .dom(".search-advanced-additional-options #search-max-post-count")
      .hasValue("5", 'has "5" populated');
    assert
      .dom(".search-query")
      .hasValue(
        "none max_posts:5",
        'has updated search term to "none max_posts:5"'
      );
  });

  test("validate advanced search when initially empty", async function (assert) {
    await visit("/search?expanded=true");
    await click(".search-advanced-options .in-likes");

    assert
      .dom(".search-advanced-options .in-likes")
      .isChecked('has "I liked" populated');

    assert
      .dom(".search-query")
      .hasValue("in:likes", 'has updated search term to "in:likes"');

    await fillIn(".search-query", "in:likesasdas");

    assert
      .dom(".search-advanced-options .in-likes")
      .isNotChecked("does not populate the likes checkbox");
  });

  test("all tags checkbox only visible for two or more tags", async function (assert) {
    await visit("/search?expanded=true");

    const tagSelector = selectKit("#search-with-tags");

    await tagSelector.expand();
    await tagSelector.selectRowByValue("monkey");

    assert.dom("input.all-tags").isNotVisible("all tags checkbox not visible");

    await tagSelector.selectRowByValue("gazelle");
    assert.dom("input.all-tags").isVisible("all tags checkbox is visible");
  });

  test("search for users", async function (assert) {
    await visit("/search");

    const typeSelector = selectKit(".search-bar .select-kit#search-type");

    await fillIn(".search-query", "admin");
    assert.dom(".fps-user-item").doesNotExist("has no user results");

    await click(".advanced-filters > summary");
    await typeSelector.expand();
    await typeSelector.selectRowByValue(SEARCH_TYPE_USERS);

    assert.dom(".search-filters").doesNotExist("has no filters");

    await click(".search-cta");

    assert.dom(".fps-user-item").exists({ count: 1 }, "has one user result");

    await typeSelector.expand();
    await typeSelector.selectRowByValue(SEARCH_TYPE_DEFAULT);

    assert
      .dom(".search-filters")
      .exists("returning to topic/posts shows filters");
    assert.dom(".fps-user-item").doesNotExist("has no user results");
  });

  test("search for categories/tags", async function (assert) {
    await visit("/search");

    await fillIn(".search-query", "none");
    const typeSelector = selectKit(".search-bar .select-kit#search-type");

    assert.dom(".fps-tag-item").doesNotExist("has no category/tag results");

    await click(".advanced-filters > summary");
    await typeSelector.expand();
    await typeSelector.selectRowByValue(SEARCH_TYPE_CATS_TAGS);
    await click(".search-cta");

    assert.dom(".search-filters").doesNotExist("has no filters");
    assert.dom(".fps-tag-item").exists({ count: 4 }, "has four tag results");

    await typeSelector.expand();
    await typeSelector.selectRowByValue(SEARCH_TYPE_DEFAULT);

    assert
      .dom(".search-filters")
      .exists("returning to topic/posts shows filters");
    assert.dom(".fps-tag-item").doesNotExist("has no tag results");
  });

  test("filters expand/collapse as expected", async function (assert) {
    await visit("/search?expanded=true");

    assert
      .dom(".search-advanced-options")
      .isVisible(
        "advanced filters are expanded when url query param is included"
      );

    await fillIn(".search-query", "none");
    await click(".search-cta");

    assert
      .dom(".advanced-filters[open]")
      .doesNotExist("launching a search collapses advanced filters");

    await visit("/search");

    assert
      .dom(".advanced-filters[open]")
      .doesNotExist("filters are collapsed when query param is not present");

    await click(".advanced-filters > summary");
    assert
      .dom(".search-advanced-options")
      .isVisible("clicking on element expands filters");
  });

  test("adds visited class to visited topics", async function (assert) {
    await visit("/search");

    await fillIn(".search-query", "discourse");
    await click(".search-cta");
    assert.dom(".visited").doesNotExist();

    await fillIn(".search-query", "discourse visited");
    await click(".search-cta");
    assert.dom(".visited").exists({ count: 1 });
  });

  test("result link click tracking is invoked", async function (assert) {
    await visit("/search");

    await fillIn(".search-query", "discourse");
    await click(".search-cta");

    await click("a.search-link:first-child");

    assert.strictEqual(currentURL(), "/t/lorem-ipsum-dolor-sit-amet/130");
    assert.true(searchResultClickTracked);
  });
});
