import {
  acceptance,
  count,
  exists,
  query,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import I18n from "I18n";
import searchFixtures from "discourse/tests/fixtures/search-fixtures";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";
import { DEFAULT_TYPE_FILTER } from "discourse/components/search-menu";

acceptance("Search - Glimmer - Anonymous", function (needs) {
  needs.user({
    experimental_search_menu_groups_enabled: true,
  });
  needs.hooks.beforeEach(() => {
    updateCurrentUser({ is_anonymous: true });
  });
  needs.pretender((server, helper) => {
    server.get("/search/query", (request) => {
      if (request.queryParams.type_filter === DEFAULT_TYPE_FILTER) {
        // posts/topics are not present in the payload by default
        return helper.response({
          users: searchFixtures["search/query"]["users"],
          categories: searchFixtures["search/query"]["categories"],
          groups: searchFixtures["search/query"]["groups"],
          grouped_search_result:
            searchFixtures["search/query"]["grouped_search_result"],
        });
      }
      return helper.response(searchFixtures["search/query"]);
    });

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

    server.get("/tag/important/notifications", () => {
      return helper.response({
        tag_notification: { id: "important", notification_level: 2 },
      });
    });
  });

  test("presence of elements", async function (assert) {
    await visit("/");
    await click("#search-button");

    assert.ok(exists("#search-term"), "it shows the search input");
    assert.ok(
      exists(".show-advanced-search"),
      "it shows full page search button"
    );
  });

  test("random quick tips", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");

    assert.ok(
      !exists(".search-menu .results ul li.search-random-quick-tip"),
      "quick tip is no longer shown"
    );
  });

  test("advanced search", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");
    await triggerKeyEvent("#search-term", "keyup", "ArrowDown");
    await click(document.activeElement);
    await click(".show-advanced-search");

    assert.strictEqual(
      query(".full-page-search").value,
      "dev",
      "it goes to full search page and preserves the search term"
    );

    assert.ok(
      exists(".search-advanced-options"),
      "advanced search is expanded"
    );
  });

  test("search button toggles search menu", async function (assert) {
    await visit("/");

    await click("#search-button");
    assert.ok(exists(".search-menu"));

    await click(".d-header"); // click outside
    assert.ok(!exists(".search-menu"));

    await click("#search-button");
    assert.ok(exists(".search-menu"));

    await click("#search-button"); // toggle same button
    assert.ok(!exists(".search-menu"));
  });

  test("initial options", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");

    assert.strictEqual(
      query(
        ".search-menu .results ul.search-menu-initial-options li:first-child .search-item-prefix"
      ).innerText.trim(),
      "dev",
      "first dropdown item includes correct prefix"
    );

    assert.strictEqual(
      query(
        ".search-menu .results ul.search-menu-initial-options li:first-child .search-item-slug"
      ).innerText.trim(),
      I18n.t("search.in_topics_posts"),
      "first dropdown item includes correct suffix"
    );

    assert.ok(
      exists(".search-menu .search-result-category ul li"),
      "shows matching category results"
    );

    assert.ok(
      exists(".search-menu .search-result-user ul li"),
      "shows matching user results"
    );
  });

  test("initial options - tag search scope", async function (assert) {
    const contextSelector = ".search-menu .results .search-menu-assistant-item";
    await visit("/tag/important");
    await click("#search-button");

    assert.strictEqual(
      query(".search-link .label-suffix").textContent.trim(),
      I18n.t("search.in"),
      "first option includes suffix"
    );

    assert.strictEqual(
      query(".search-link .search-item-tag").textContent.trim(),
      "important",
      "frst option includes tag"
    );

    await fillIn("#search-term", "smth");
    const secondOption = queryAll(contextSelector)[1];

    assert.strictEqual(
      secondOption.querySelector(".search-item-prefix").textContent.trim(),
      "smth",
      "second option includes term"
    );

    assert.strictEqual(
      secondOption.querySelector(".label-suffix").textContent.trim(),
      I18n.t("search.in"),
      "second option includes suffix"
    );

    assert.strictEqual(
      secondOption.querySelector(".search-item-tag").textContent.trim(),
      "important",
      "second option includes tag"
    );
  });

  test("initial options - category search scope", async function (assert) {
    const contextSelector = ".search-menu .results .search-menu-assistant-item";
    await visit("/c/bug");
    await click("#search-button");
    await fillIn("#search-term", "smth");
    const secondOption = queryAll(contextSelector)[1];

    assert.strictEqual(
      secondOption.querySelector(".search-item-prefix").textContent.trim(),
      "smth",
      "second option includes term"
    );

    assert.strictEqual(
      secondOption.querySelector(".label-suffix").textContent.trim(),
      I18n.t("search.in"),
      "second option includes suffix"
    );

    assert.strictEqual(
      secondOption.querySelector(".category-name").textContent.trim(),
      "bug",
      "second option includes category slug"
    );

    assert.ok(
      exists(`${contextSelector} span.badge-wrapper`),
      "category badge is a span (i.e. not a link)"
    );
  });

  test("initial options - topic search scope", async function (assert) {
    const contextSelector = ".search-menu .results .search-menu-assistant-item";
    await visit("/t/internationalization-localization/280");
    await click("#search-button");
    await fillIn("#search-term", "smth");
    const secondOption = queryAll(contextSelector)[1];

    assert.strictEqual(
      secondOption.querySelector(".search-item-prefix").textContent.trim(),
      "smth",
      "second option includes term"
    );

    assert.strictEqual(
      secondOption.querySelector(".label-suffix").textContent.trim(),
      I18n.t("search.in_this_topic"),
      "second option includes suffix"
    );
  });

  test("initial options - topic search scope - 'in all topics' searches in all topics", async function (assert) {
    await visit("/t/internationalization-localization/280/1");
    await click("#search-button");
    await fillIn("#search-term", "foo");
    // select 'in all topics and posts'
    await click(
      ".search-menu .results .search-menu-initial-options .search-menu-assistant-item:first-child"
    );
    assert.ok(
      exists(".search-result-topic"),
      "search result is a list of topics"
    );
  });

  test("initial options - topic search scope - 'in this topic' searches posts within topic", async function (assert) {
    await visit("/t/internationalization-localization/280/1");
    await click("#search-button");
    await fillIn("#search-term", "foo");
    // select 'in this topic'
    await click(
      ".search-menu .results .search-menu-initial-options .search-menu-assistant-item:nth-child(2)"
    );
    assert.ok(
      exists(".search-result-post"),
      "search result is a list of posts"
    );
  });

  test("initial options - topic search scope - keep 'in this topic' filter in full page search", async function (assert) {
    await visit("/t/internationalization-localization/280/1");
    await click("#search-button");
    await fillIn("#search-term", "proper");
    await triggerKeyEvent(document.activeElement, "keyup", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    await click(document.activeElement);
    await click(".show-advanced-search");

    assert.strictEqual(
      query(".full-page-search").value,
      "proper topic:280",
      "it goes to full search page and preserves search term + context"
    );

    assert.ok(
      exists(".search-advanced-options"),
      "advanced search is expanded"
    );
  });

  test("initial options - topic search scope - special case when matching a single user", async function (assert) {
    await visit("/t/internationalization-localization/280/1");
    await click("#search-button");
    await fillIn("#search-term", "@admin");

    assert.strictEqual(count(".search-menu-assistant-item"), 2);
    assert.strictEqual(
      query(
        ".search-menu-assistant-item:first-child .search-item-slug .label-suffix"
      ).textContent.trim(),
      I18n.t("search.in_topics_posts"),
      "first result hints at global search"
    );

    assert.strictEqual(
      query(
        ".search-menu-assistant-item:nth-child(2) .search-item-slug .label-suffix"
      ).textContent.trim(),
      I18n.t("search.in_this_topic"),
      "second result hints at search within current topic"
    );
  });

  test("initial options - user search scope", async function (assert) {
    const contextSelector = ".search-menu .results .search-menu-assistant-item";
    await visit("/u/eviltrout");
    await click("#search-button");
    await fillIn("#search-term", "smth");
    const secondOption = queryAll(contextSelector)[1];

    assert.strictEqual(
      secondOption.querySelector(".search-item-prefix").textContent.trim(),
      "smth",
      "second option includes term for user-scoped search"
    );

    assert.strictEqual(
      secondOption.querySelector(".label-suffix").textContent.trim(),
      I18n.t("search.in_posts_by", { username: "eviltrout" }),
      "second option includes suffix for user-scoped search"
    );
  });

  test("topic results", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");
    await triggerKeyEvent("#search-term", "keyup", "ArrowDown");
    await click(document.activeElement);

    assert.ok(
      exists(".search-menu .search-result-topic ul li"),
      "shows topic results"
    );

    assert.ok(
      exists(".search-menu .results ul li .topic-title[data-topic-id]"),
      "topic has data-topic-id"
    );
  });

  test("topic results - topic search scope", async function (assert) {
    await visit("/t/internationalization-localization/280/1");
    await click("#search-button");
    await fillIn("#search-term", "a proper");
    await triggerKeyEvent(document.activeElement, "keyup", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    await click(document.activeElement);

    assert.ok(
      exists(".search-menu .search-result-post ul li"),
      "clicking second option scopes search to current topic"
    );

    assert.strictEqual(
      query("#post_7 span.highlighted").textContent.trim(),
      "a proper",
      "highlights the post correctly"
    );

    assert.ok(
      exists(".search-menu .search-context"),
      "search context indicator is visible"
    );

    await click(".clear-search");
    assert.strictEqual(
      query("#search-term").textContent.trim(),
      "",
      "clear button works"
    );

    await click(".search-context");
    assert.ok(
      !exists(".search-menu .search-context"),
      "search context indicator is no longer visible"
    );

    await fillIn("#search-term", "dev");
    await query("#search-term").focus();
    await triggerKeyEvent(document.activeElement, "keyup", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    await click(document.activeElement);

    assert.ok(
      exists(".search-menu .search-context"),
      "search context indicator is visible"
    );

    await fillIn("#search-term", "");
    await query("#search-term").focus();
    await triggerKeyEvent("#search-term", "keyup", "Backspace");

    assert.ok(
      !exists(".search-menu .search-context"),
      "backspace resets search context"
    );
  });

  test("topic results - search result escapes html in topic title", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");
    await triggerKeyEvent("#search-term", "keyup", "Enter");

    assert.ok(
      exists(
        ".search-menu .search-result-topic .item .topic-title span#topic-with-html"
      ),
      "html in the topic title is properly escaped"
    );
  });

  test("topic results - search result escapes emojis in topic title", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");
    await triggerKeyEvent("#search-term", "keyup", "Enter");

    assert.ok(
      exists(
        ".search-menu .search-result-topic .item .topic-title img[alt='+1']"
      ),
      ":+1: in the topic title is properly converted to an emoji"
    );
  });
});

acceptance("Search - Glimmer - Authenticated", function (needs) {
  needs.user({
    experimental_search_menu_groups_enabled: true,
  });
  needs.settings({
    log_search_queries: true,
    allow_uncategorized_topics: true,
  });

  needs.pretender((server, helper) => {
    server.get("/search/query", (request) => {
      if (request.queryParams.term.includes("empty")) {
        return helper.response({
          posts: [],
          users: [],
          categories: [],
          tags: [],
          groups: [],
          grouped_search_result: {
            more_posts: null,
            more_users: null,
            more_categories: null,
            term: "plans test",
            search_log_id: 1,
            more_full_page_results: null,
            can_create_topic: true,
            error: null,
            type_filter: null,
            post_ids: [],
            user_ids: [],
            category_ids: [],
            tag_ids: [],
            group_ids: [],
          },
        });
      }

      return helper.response(searchFixtures["search/query"]);
    });

    server.get("/inline-onebox", () =>
      helper.response({
        "inline-oneboxes": [
          {
            url: "http://www.something.com",
            title: searchFixtures["search/query"].topics[0].title,
          },
        ],
      })
    );
  });

  test("full page search - the right filters are shown", async function (assert) {
    const inSelector = selectKit(".select-kit#in");
    await visit("/search?expanded=true");
    await inSelector.expand();

    assert.ok(inSelector.rowByValue("first").exists());
    assert.ok(inSelector.rowByValue("pinned").exists());
    assert.ok(inSelector.rowByValue("wiki").exists());
    assert.ok(inSelector.rowByValue("images").exists());

    assert.ok(inSelector.rowByValue("unseen").exists());
    assert.ok(inSelector.rowByValue("posted").exists());
    assert.ok(inSelector.rowByValue("watching").exists());
    assert.ok(inSelector.rowByValue("tracking").exists());
    assert.ok(inSelector.rowByValue("bookmarks").exists());

    assert.ok(exists(".search-advanced-options .in-likes"));
    assert.ok(exists(".search-advanced-options .in-private"));
    assert.ok(exists(".search-advanced-options .in-seen"));
  });

  test("topic results - topic search scope - works with empty result sets", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#search-button");
    await fillIn("#search-term", "plans");
    await triggerKeyEvent("#search-term", "keyup", "ArrowDown");
    await click(document.activeElement);

    assert.notStrictEqual(count(".search-menu .results .item"), 0);

    await fillIn("#search-term", "plans empty");
    await triggerKeyEvent("#search-term", "keyup", 13);

    assert.strictEqual(count(".search-menu .results .item"), 0);
    assert.strictEqual(count(".search-menu .results .no-results"), 1);
    assert.strictEqual(
      query(".search-menu .results .no-results").innerText,
      I18n.t("search.no_results")
    );
  });

  test("search menu keyboard navigation", async function (assert) {
    const container = ".search-menu .results";
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");
    assert.ok(exists(query(`${container} ul li`)), "has a list of items");

    await triggerKeyEvent("#search-term", "keyup", "Enter");
    assert.ok(
      exists(query(`${container} .search-result-topic`)),
      "has topic results"
    );

    await triggerKeyEvent("#search-term", "keyup", "ArrowDown");
    assert.strictEqual(
      document.activeElement.getAttribute("href"),
      query(`${container} li:first-child a`).getAttribute("href"),
      "arrow down selects first element"
    );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    assert.strictEqual(
      document.activeElement.getAttribute("href"),
      query(`${container} li:nth-child(2) a`).getAttribute("href"),
      "arrow down selects next element"
    );

    // navigate to the `more link`
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    assert.strictEqual(
      document.activeElement.getAttribute("href"),
      "/search?q=dev",
      "arrow down sets focus to more results link"
    );

    await triggerKeyEvent("#search-term", "keyup", "Escape");
    assert.strictEqual(
      document.activeElement,
      query("#search-button"),
      "Escaping search returns focus to search button"
    );
    assert.ok(!exists(".search-menu:visible"), "Esc removes search dropdown");

    await click("#search-button");
    await triggerKeyEvent(document.activeElement, "keyup", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowUp");
    assert.strictEqual(
      document.activeElement.tagName.toLowerCase(),
      "input",
      "arrow up sets focus to search term input"
    );

    await triggerKeyEvent("#search-term", "keyup", "Enter");
    assert.ok(
      exists(query(`${container} .search-result-topic`)),
      "has topic results"
    );

    await triggerKeyEvent("#search-term", "keyup", "Enter");
    assert.ok(
      exists(query(`.search-container`)),
      "second Enter hit goes to full page search"
    );
    assert.ok(
      !exists(query(`.search-menu`)),
      "search dropdown is collapsed after second Enter hit"
    );

    //new search launched, Enter key should be reset
    await click("#search-button");
    assert.ok(exists(query(`${container} ul li`)), "has a list of items");

    await triggerKeyEvent("#search-term", "keyup", "Enter");
    assert.ok(exists(query(`.search-menu`)), "search dropdown is visible");
  });

  test("search menu keyboard navigation - while composer is open", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".reply");
    await fillIn(".d-editor-input", "a link");
    await click("#search-button");
    await fillIn("#search-term", "dev");
    await triggerKeyEvent("#search-term", "keyup", "Enter");
    await triggerKeyEvent(document.activeElement, "keyup", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", 65); // maps to lowercase a

    assert.ok(
      query(".d-editor-input").value.includes("a link"),
      "still has the original composer content"
    );

    assert.ok(
      query(".d-editor-input").value.includes(
        searchFixtures["search/query"].topics[0].slug
      ),
      "adds link from search to composer"
    );
  });

  test("initial options - recent search results", async function (assert) {
    await visit("/");
    await click("#search-button");

    assert.strictEqual(
      query(
        ".search-menu .search-menu-recent li:nth-of-type(1) .search-link"
      ).textContent.trim(),
      "yellow",
      "shows first recent search"
    );

    assert.strictEqual(
      query(
        ".search-menu .search-menu-recent li:nth-of-type(2) .search-link"
      ).textContent.trim(),
      "blue",
      "shows second recent search"
    );
  });
});

acceptance("Search - Glimmer - with tagging enabled", function (needs) {
  needs.user({
    experimental_search_menu_groups_enabled: true,
  });
  needs.settings({ tagging_enabled: true });

  test("topic results - displays tags", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");
    await triggerKeyEvent("#search-term", "keyup", 13);

    assert.strictEqual(
      query(
        ".search-menu .results ul li:nth-of-type(1) .discourse-tags"
      ).textContent.trim(),
      "dev slow",
      "tags displayed in search results"
    );
  });

  test("initial results - displays tag shortcuts", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dude #monk");
    const firstItem =
      ".search-menu .results ul.search-menu-assistant .search-link";

    assert.ok(exists(query(firstItem)));

    const firstTag = query(`${firstItem} .search-item-tag`).textContent.trim();
    assert.strictEqual(firstTag, "monkey");
  });
});

acceptance("Search - Glimmer - assistant", function (needs) {
  needs.user({
    experimental_search_menu_groups_enabled: true,
  });

  needs.pretender((server, helper) => {
    server.get("/search/query", (request) => {
      if (request.queryParams["search_context[type]"] === "private_messages") {
        // return only one result for PM search
        return helper.response({
          posts: [
            {
              id: 3833,
              name: "Bill Dudney",
              username: "bdudney",
              avatar_template:
                "/user_avatar/meta.discourse.org/bdudney/{size}/8343_1.png",
              uploaded_avatar_id: 8343,
              created_at: "2013-02-07T17:46:57.469Z",
              cooked:
                "<p>I've gotten vagrant up and running with a development environment but it's taking forever to load.</p>\n\n<p>For example <a href=\"http://192.168.10.200:3000/\" rel=\"nofollow\">http://192.168.10.200:3000/</a> takes tens of seconds to load.</p>\n\n<p>I'm running the whole stack on a new rMBP with OS X 10.8.2.</p>\n\n<p>Any ideas of what I've done wrong? Or is this just a function of being on the bleeding edge?</p>\n\n<p>Thanks,</p>\n\n<p>-bd</p>",
              post_number: 1,
              post_type: 1,
              updated_at: "2013-02-07T17:46:57.469Z",
              like_count: 0,
              reply_count: 1,
              reply_to_post_number: null,
              quote_count: 0,
              incoming_link_count: 4422,
              reads: 327,
              score: 21978.4,
              yours: false,
              topic_id: 2179,
              topic_slug: "development-mode-super-slow",
              display_username: "Bill Dudney",
              primary_group_name: null,
              version: 2,
              can_edit: false,
              can_delete: false,
              can_recover: false,
              user_title: null,
              actions_summary: [
                {
                  id: 2,
                  count: 0,
                  hidden: false,
                  can_act: false,
                },
                {
                  id: 3,
                  count: 0,
                  hidden: false,
                  can_act: false,
                },
                {
                  id: 4,
                  count: 0,
                  hidden: false,
                  can_act: false,
                },
                {
                  id: 5,
                  count: 0,
                  hidden: true,
                  can_act: false,
                },
                {
                  id: 6,
                  count: 0,
                  hidden: false,
                  can_act: false,
                },
                {
                  id: 7,
                  count: 0,
                  hidden: false,
                  can_act: false,
                },
                {
                  id: 8,
                  count: 0,
                  hidden: false,
                  can_act: false,
                },
              ],
              moderator: false,
              admin: false,
              staff: false,
              user_id: 1828,
              hidden: false,
              hidden_reason_id: null,
              trust_level: 1,
              deleted_at: null,
              user_deleted: false,
              edit_reason: null,
              can_view_edit_history: true,
              wiki: false,
              blurb:
                "I've gotten vagrant up and running with a development environment but it's taking forever to load. For example http://192.168.10.200:3000/ takes...",
            },
          ],
          topics: [
            {
              id: 2179,
              title: "Development mode super slow",
              fancy_title: "Development mode super slow",
              slug: "development-mode-super-slow",
              posts_count: 72,
              reply_count: 53,
              highest_post_number: 73,
              image_url: null,
              created_at: "2013-02-07T17:46:57.262Z",
              last_posted_at: "2015-04-17T08:08:26.671Z",
              bumped: true,
              bumped_at: "2015-04-17T08:08:26.671Z",
              unseen: false,
              pinned: false,
              unpinned: null,
              visible: true,
              closed: false,
              archived: false,
              bookmarked: null,
              liked: null,
              views: 9538,
              like_count: 45,
              has_summary: true,
              archetype: "regular",
              last_poster_username: null,
              category_id: 7,
              pinned_globally: false,
              posters: [],
              tags: ["dev", "slow"],
              tags_descriptions: {
                dev: "dev description",
                slow: "slow description",
              },
            },
          ],
          grouped_search_result: {
            term: "emoji",
            post_ids: [3833],
          },
        });
      }
      return helper.response(searchFixtures["search/query"]);
    });

    server.get("/tag/dev/notifications", () => {
      return helper.response({
        tag_notification: { id: "dev", notification_level: 2 },
      });
    });

    server.get("/tags/c/bug/1/dev/l/latest.json", () => {
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
              name: "dev",
              topic_count: 1,
            },
          ],
          topics: [],
        },
      });
    });

    server.get("/tags/intersection/dev/foo.json", () => {
      return helper.response({
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

    server.get("/u/search/users", () => {
      return helper.response({
        users: [
          {
            username: "TeaMoe",
            name: "TeaMoe",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/t/41988e/{size}.png",
          },
          {
            username: "TeamOneJ",
            name: "J Cobb",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/t/3d9bf3/{size}.png",
          },
          {
            username: "kudos",
            name: "Team Blogeto.com",
            avatar_template:
              "/user_avatar/meta.discourse.org/kudos/{size}/62185_1.png",
          },
        ],
      });
    });
  });

  test("initial options - shows category shortcuts when typing #", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "#");

    assert.strictEqual(
      query(
        ".search-menu .results ul.search-menu-assistant .search-link .category-name"
      ).innerText,
      "support"
    );
  });

  test("initial options - tag search scope - shows category / tag combination shortcut when both are present", async function (assert) {
    await visit("/tags/c/bug/dev");
    await click("#search-button");

    assert.strictEqual(
      query(".search-menu .results ul.search-menu-assistant .category-name")
        .innerText,
      "bug",
      "Category is displayed"
    );

    assert.strictEqual(
      query(".search-menu .results ul.search-menu-assistant .search-item-tag")
        .innerText,
      "dev",
      "Tag is displayed"
    );
  });

  test("initial options - tag and category search scope - updates tag / category combination search suggestion when typing", async function (assert) {
    await visit("/tags/c/bug/dev");
    await click("#search-button");
    await fillIn("#search-term", "foo bar");

    assert.strictEqual(
      query(
        ".search-menu .results ul.search-menu-assistant .search-item-prefix"
      ).innerText,
      "foo bar",
      "Input is applied to search query"
    );

    assert.strictEqual(
      query(".search-menu .results ul.search-menu-assistant .category-name")
        .innerText,
      "bug"
    );

    assert.strictEqual(
      query(".search-menu .results ul.search-menu-assistant .search-item-tag")
        .innerText,
      "dev",
      "Tag is displayed"
    );
  });

  test("initial options - tag intersection search scope - shows tag combination shortcut when visiting tag intersection", async function (assert) {
    await visit("/tags/intersection/dev/foo");
    await click("#search-button");

    assert.strictEqual(
      query(".search-menu .results ul.search-menu-assistant .search-item-tag")
        .innerText,
      "tags:dev+foo",
      "Tags are displayed"
    );
  });

  test("initial options - tag intersection search scope - updates tag intersection search suggestion when typing", async function (assert) {
    await visit("/tags/intersection/dev/foo");
    await click("#search-button");
    await fillIn("#search-term", "foo bar");

    assert.strictEqual(
      query(
        ".search-menu .results ul.search-menu-assistant .search-item-prefix"
      ).innerText,
      "foo bar",
      "Input is applied to search query"
    );

    assert.strictEqual(
      query(".search-menu .results ul.search-menu-assistant .search-item-tag")
        .innerText,
      "tags:dev+foo",
      "Tags are displayed"
    );
  });

  test("initial options - shows in: shortcuts", async function (assert) {
    await visit("/");
    await click("#search-button");
    const firstTarget =
      ".search-menu .results ul.search-menu-assistant .search-link ";

    await fillIn("#search-term", "in:");
    assert.strictEqual(
      query(firstTarget.concat(".search-item-slug")).innerText,
      "in:title",
      "keyword is present in suggestion"
    );

    await fillIn("#search-term", "sam in:");
    assert.strictEqual(
      query(firstTarget.concat(".search-item-prefix")).innerText,
      "sam",
      "term is present in suggestion"
    );
    assert.strictEqual(
      query(firstTarget.concat(".search-item-slug")).innerText,
      "in:title",
      "keyword is present in suggestion"
    );

    await fillIn("#search-term", "in:mess");
    assert.strictEqual(query(firstTarget).innerText, "in:messages");
  });

  test("initial options - user search scope - shows users when typing @", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "@");
    const firstUser =
      ".search-menu .results ul.search-menu-assistant .search-item-user";
    const firstUsername = query(firstUser).innerText.trim();

    assert.strictEqual(firstUsername, "TeaMoe");

    await click(query(firstUser));
    assert.strictEqual(query("#search-term").value, `@${firstUsername}`);
  });

  test("initial options - private message search scope - shows 'in messages' button when in an inbox", async function (assert) {
    await visit("/u/charlie/messages");
    await click("#search-button");

    assert.ok(exists(".btn.search-context"), "it shows the button");

    await fillIn("#search-term", "");
    await query("input#search-term").focus();
    await triggerKeyEvent("input#search-term", "keyup", "Backspace");

    assert.notOk(exists(".btn.search-context"), "it removes the button");

    await click(".d-header");
    await click("#search-button");
    assert.ok(
      exists(".btn.search-context"),
      "it shows the button when reinvoking search"
    );

    await fillIn("#search-term", "emoji");
    await query("input#search-term").focus();
    await triggerKeyEvent("#search-term", "keyup", "Enter");

    assert.strictEqual(
      count(".search-menu .search-result-topic"),
      1,
      "it passes the PM search context to the search query"
    );
  });

  test("topic results - updates search term when selecting a initial category option", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "sam #");
    const firstCategory =
      ".search-menu .results ul.search-menu-assistant .search-link";
    const firstCategoryName = query(
      `${firstCategory} .category-name`
    ).innerText;
    await click(firstCategory);

    assert.strictEqual(
      query("#search-term").value,
      `sam #${firstCategoryName}`
    );
  });
});
