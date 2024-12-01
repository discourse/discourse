import {
  click,
  currentURL,
  fillIn,
  focus,
  triggerEvent,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import { DEFAULT_TYPE_FILTER } from "discourse/components/search-menu";
import { withPluginApi } from "discourse/lib/plugin-api";
import searchFixtures from "discourse/tests/fixtures/search-fixtures";
import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

const clickOutside = () => triggerEvent("header.d-header", "pointerdown");

acceptance("Search - Anonymous", function (needs) {
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

    assert.dom("#search-term").exists("shows the search input");
    assert.dom(".show-advanced-search").exists("shows full page search button");
  });

  test("random quick tips", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");

    assert
      .dom(".search-menu .results ul li.search-random-quick-tip")
      .doesNotExist("quick tip is no longer shown");
  });

  test("advanced search", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");
    await triggerKeyEvent("#search-term", "keyup", "ArrowDown");
    await click(document.activeElement);
    await click(".show-advanced-search");

    assert
      .dom(".full-page-search")
      .hasValue(
        "dev",
        "goes to full search page and preserves the search term"
      );

    assert
      .dom(".search-menu .search-menu-panel")
      .doesNotExist("closes search menu after clicking advanced search button");

    assert
      .dom(".search-advanced-options")
      .exists("advanced search is expanded");
  });

  test("search button toggles search menu", async function (assert) {
    await visit("/");

    await click("#search-button");
    assert.dom(".search-menu").exists();

    await clickOutside();
    assert.dom(".search-menu").doesNotExist();

    await click("#search-button");
    assert.dom(".search-menu").exists();

    await click("#search-button"); // toggle same button
    assert.dom(".search-menu").doesNotExist();
  });

  test("initial options", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");

    assert
      .dom(
        ".search-menu .results ul.search-menu-initial-options li:first-child .search-item-prefix"
      )
      .hasText("dev", "first dropdown item includes correct prefix");

    assert
      .dom(
        ".search-menu .results ul.search-menu-initial-options li:first-child .search-item-slug"
      )
      .hasText(
        i18n("search.in_topics_posts"),
        "first dropdown item includes correct suffix"
      );

    assert
      .dom(".search-menu .search-result-category ul li")
      .exists("shows matching category results");

    assert
      .dom(".search-menu .search-result-user ul li")
      .exists("shows matching user results");
  });

  test("initial options - tag search scope", async function (assert) {
    const contextSelector = ".search-menu .results .search-menu-assistant-item";
    await visit("/tag/important");
    await click("#search-button");

    assert
      .dom(".search-link .label-suffix")
      .hasText(i18n("search.in"), "first option includes suffix");

    assert
      .dom(".search-link .search-item-tag")
      .hasText("important", "first option includes tag");

    await fillIn("#search-term", "smth");
    const secondOption = queryAll(contextSelector)[1];

    assert
      .dom(".search-item-prefix", secondOption)
      .hasText("smth", "second option includes term");

    assert
      .dom(".label-suffix", secondOption)
      .hasText(i18n("search.in"), "second option includes suffix");

    assert
      .dom(".search-item-tag", secondOption)
      .hasText("important", "second option includes tag");
  });

  test("initial options - category search scope", async function (assert) {
    const contextSelector = ".search-menu .results .search-menu-assistant-item";
    await visit("/c/bug");
    await click("#search-button");
    await fillIn("#search-term", "smth");
    const secondOption = queryAll(contextSelector)[1];

    assert
      .dom(".search-item-prefix", secondOption)
      .hasText("smth", "second option includes term");

    assert
      .dom(".label-suffix", secondOption)
      .hasText(i18n("search.in"), "second option includes suffix");

    assert
      .dom(".badge-category__name", secondOption)
      .hasText("bug", "second option includes category slug");

    assert
      .dom(`${contextSelector} span.badge-category__wrapper`)
      .exists("category badge is a span (i.e. not a link)");
  });

  test("initial options - topic search scope", async function (assert) {
    const contextSelector = ".search-menu .results .search-menu-assistant-item";
    await visit("/t/internationalization-localization/280");
    await click("#search-button");
    await fillIn("#search-term", "smth");
    const secondOption = queryAll(contextSelector)[1];

    assert
      .dom(".search-item-prefix", secondOption)
      .hasText("smth", "second option includes term");

    assert
      .dom(".label-suffix", secondOption)
      .hasText(i18n("search.in_this_topic"), "second option includes suffix");
  });

  test("initial options - topic search scope - 'in all topics' searches in all topics", async function (assert) {
    await visit("/t/internationalization-localization/280/1");
    await click("#search-button");
    await fillIn("#search-term", "foo");
    // select 'in all topics and posts'
    await click(
      ".search-menu .results .search-menu-initial-options .search-menu-assistant-item:first-child"
    );
    assert
      .dom(".search-result-topic")
      .exists("search result is a list of topics");
  });

  test("initial options - topic search scope - 'in this topic' searches posts within topic", async function (assert) {
    await visit("/t/internationalization-localization/280/1");
    await click("#search-button");
    await fillIn("#search-term", "foo");
    // select 'in this topic'
    await click(
      ".search-menu .results .search-menu-initial-options .search-menu-assistant-item:nth-child(2)"
    );
    assert
      .dom(".search-result-post")
      .exists("search result is a list of posts");
  });

  test("initial options - topic search scope - keep 'in this topic' filter in full page search", async function (assert) {
    await visit("/t/internationalization-localization/280/1");
    await click("#search-button");
    await fillIn("#search-term", "proper");
    await triggerKeyEvent(document.activeElement, "keyup", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    await click(document.activeElement);
    await click(".show-advanced-search");

    assert
      .dom(".full-page-search")
      .hasValue(
        "proper topic:280",
        "goes to full search page and preserves search term + context"
      );

    assert
      .dom(".search-advanced-options")
      .exists("advanced search is expanded");
  });

  test("initial options - topic search scope - special case when matching a single user", async function (assert) {
    await visit("/t/internationalization-localization/280/1");
    await click("#search-button");
    await fillIn("#search-term", "@admin");

    assert.dom(".search-menu-assistant-item").exists({ count: 2 });
    assert
      .dom(
        ".search-menu-assistant-item:first-child .search-item-slug .label-suffix"
      )
      .hasText(
        i18n("search.in_topics_posts"),
        "first result hints at global search"
      );

    assert
      .dom(
        ".search-menu-assistant-item:nth-child(2) .search-item-slug .label-suffix"
      )
      .hasText(
        i18n("search.in_this_topic"),
        "second result hints at search within current topic"
      );
  });

  test("initial options - user search scope", async function (assert) {
    const contextSelector = ".search-menu .results .search-menu-assistant-item";
    await visit("/u/eviltrout");
    await click("#search-button");
    await fillIn("#search-term", "smth");
    const secondOption = queryAll(contextSelector)[1];

    assert
      .dom(".search-item-prefix", secondOption)
      .hasText("smth", "second option includes term for user-scoped search");

    assert
      .dom(".label-suffix", secondOption)
      .hasText(
        i18n("search.in_posts_by", { username: "eviltrout" }),
        "second option includes suffix for user-scoped search"
      );
  });

  test("topic results", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");
    await triggerKeyEvent("#search-term", "keyup", "ArrowDown");
    await click(document.activeElement);

    assert
      .dom(".search-menu .search-result-topic ul li")
      .exists("shows topic results");

    assert
      .dom(".search-menu .results ul li .topic-title[data-topic-id]")
      .exists("topic has data-topic-id");
  });

  test("topic results - topic search scope", async function (assert) {
    await visit("/t/internationalization-localization/280/1");
    await click("#search-button");
    await fillIn("#search-term", "a proper");
    await triggerKeyEvent(document.activeElement, "keyup", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    await click(document.activeElement);

    assert
      .dom(".search-menu .search-result-post ul li")
      .exists("clicking second option scopes search to current topic");

    assert
      .dom("#post_7 span.highlighted")
      .hasText("a proper", "highlights the post correctly");

    assert
      .dom(".search-menu .search-context")
      .exists("search context indicator is visible");

    await click(".clear-search");
    assert.dom("#search-term").hasNoText("clear button works");

    await click(".search-context");
    assert
      .dom(".search-menu .search-context")
      .doesNotExist("search context indicator is no longer visible");

    await fillIn("#search-term", "dev");
    focus("#search-term");
    await triggerKeyEvent(document.activeElement, "keyup", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    await click(document.activeElement);

    assert
      .dom(".search-menu .search-context")
      .exists("search context indicator is visible");

    await fillIn("#search-term", "");
    focus("#search-term");
    await triggerKeyEvent("#search-term", "keyup", "Backspace");

    assert
      .dom(".search-menu .search-context")
      .doesNotExist("backspace resets search context");
  });

  test("topic results - search result escapes html in topic title", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");
    await triggerKeyEvent("#search-term", "keyup", "Enter");

    assert
      .dom(
        ".search-menu .search-result-topic .item .topic-title span#topic-with-html"
      )
      .exists("html in the topic title is properly escaped");
  });

  test("topic results - search result escapes emojis in topic title", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");
    await triggerKeyEvent("#search-term", "keyup", "Enter");

    assert
      .dom(".search-menu .search-result-topic .item .topic-title img[alt='+1']")
      .exists(":+1: in the topic title is properly converted to an emoji");
  });

  test("pressing escape correctly closes the menu", async function (assert) {
    await visit("/");
    await click("#search-button");
    await focus(".show-advanced-search");
    await triggerKeyEvent("#search-term", "keydown", "Escape");

    assert.dom(".search-menu-panel").doesNotExist();
  });
});

acceptance("Search - Authenticated", function (needs) {
  needs.user();
  needs.settings({
    log_search_queries: true,
    allow_uncategorized_topics: true,
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
      } else if (request.queryParams.term.includes("empty")) {
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
      } else {
        return helper.response(searchFixtures["search/query"]);
      }
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

    server.get("/t/2179.json", () => {
      return helper.response({});
    });

    server.post("/search/click", () => {
      return helper.response({ success: "OK" });
    });
  });

  test("full page search - the right filters are shown", async function (assert) {
    const inSelector = selectKit(".select-kit#in");
    await visit("/search?expanded=true");
    await inSelector.expand();

    assert.true(inSelector.rowByValue("first").exists());
    assert.true(inSelector.rowByValue("pinned").exists());
    assert.true(inSelector.rowByValue("wiki").exists());
    assert.true(inSelector.rowByValue("images").exists());

    assert.true(inSelector.rowByValue("unseen").exists());
    assert.true(inSelector.rowByValue("posted").exists());
    assert.true(inSelector.rowByValue("watching").exists());
    assert.true(inSelector.rowByValue("tracking").exists());
    assert.true(inSelector.rowByValue("bookmarks").exists());

    assert.dom(".search-advanced-options .in-likes").exists();
    assert.dom(".search-advanced-options .in-private").exists();
    assert.dom(".search-advanced-options .in-seen").exists();
  });

  test("topic results - topic search scope - works with empty result sets", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#search-button");
    await fillIn("#search-term", "plans");
    await triggerKeyEvent("#search-term", "keyup", "ArrowDown");
    await click(document.activeElement);

    assert.dom(".search-menu .results .item").exists();

    await fillIn("#search-term", "plans empty");
    await triggerKeyEvent("#search-term", "keyup", 13);

    assert.dom(".search-menu .results .item").doesNotExist();
    assert.dom(".search-menu .results .no-results").exists({ count: 1 });
    assert
      .dom(".search-menu .results .no-results")
      .hasText(i18n("search.no_results"));
  });

  test("topic results - topic search scope - clicking a search result navigates to topic url", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "Development");
    await triggerKeyEvent(document.activeElement, "keyup", "Enter");

    assert
      .dom(".search-menu .results li a.search-link")
      .hasAttribute("href", "/t/development-mode-super-slow/2179");

    await click(".search-menu .results li a.search-link");
    assert.strictEqual(
      currentURL(),
      "/t/development-mode-super-slow/2179",
      "redirects to clicked search result url"
    );
  });

  test("topic results - search result escapes html in topic title when use_pg_headlines_for_excerpt is true", async function (assert) {
    this.siteSettings.use_pg_headlines_for_excerpt = true;
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");
    await triggerKeyEvent("#search-term", "keyup", "Enter");

    assert
      .dom(
        ".search-menu .search-result-topic .item:first-of-type .topic-title span.search-highlight"
      )
      .exists("html in the topic title is properly escaped");
  });

  test("search menu keyboard navigation", async function (assert) {
    const container = ".search-menu .results";
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");
    assert.dom(`${container} ul li`).exists("has a list of items");

    await triggerKeyEvent("#search-term", "keyup", "Enter");
    assert.dom(`${container} .search-result-topic`).exists("has topic results");

    await triggerKeyEvent("#search-term", "keyup", "ArrowDown");
    assert
      .dom(`${container} li:first-child a`)
      .isFocused("arrow down selects first element");

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    assert
      .dom(`${container} li:nth-child(2) a`)
      .isFocused("arrow down selects next element");

    // navigate to the `more link`
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    assert
      .dom(document.activeElement)
      .hasAttribute(
        "href",
        "/search?q=dev",
        "arrow down sets focus to more results link"
      );

    await triggerKeyEvent("#search-term", "keydown", "Escape");
    assert
      .dom("#search-button")
      .isFocused("Escaping search returns focus to search button");
    assert.dom(".search-menu").doesNotExist("Esc removes search dropdown");

    await click("#search-button");
    await triggerKeyEvent(document.activeElement, "keyup", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowUp");
    assert.strictEqual(
      document.activeElement.tagName.toLowerCase(),
      "input",
      "arrow up sets focus to search term input"
    );

    await triggerKeyEvent("#search-term", "keyup", "Enter");
    assert.dom(`${container} .search-result-topic`).exists("has topic results");

    await triggerKeyEvent("#search-term", "keyup", "Enter");
    assert
      .dom(".search-container")
      .exists("second Enter hit goes to full page search");
    assert
      .dom(".search-menu")
      .doesNotExist("search dropdown is collapsed after second Enter hit");

    // new search launched, Enter key should be reset
    await click("#search-button");
    assert.dom(`${container} ul li`).exists("has a list of items");

    await triggerKeyEvent("#search-term", "keyup", "Enter");
    assert.dom(`.search-menu`).exists("search dropdown is visible");
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

    assert
      .dom(".d-editor-input")
      .hasValue(/a link/, "still has the original composer content");

    assert.true(
      document
        .querySelector(".d-editor-input")
        .value.includes(searchFixtures["search/query"].topics[0].slug),
      "adds link from search to composer"
    );
  });

  // see https://meta.discourse.org/t/keyboard-navigation-messes-up-the-search-menu/285405
  test("search menu keyboard navigation - on 'Enter' keydown navigate to selected search item url", async function (assert) {
    await visit("/");
    await triggerKeyEvent(document, "keypress", "J");
    await click("#search-button");
    await fillIn("#search-term", "Development");
    await triggerKeyEvent(document.activeElement, "keyup", "Enter");
    await triggerKeyEvent(document.activeElement, "keyup", "ArrowDown");

    assert
      .dom(document.activeElement)
      .hasAttribute(
        "href",
        "/t/development-mode-super-slow/2179",
        "first search result is highlighted"
      );

    await triggerKeyEvent(document.activeElement, "keydown", "Enter");
    assert.strictEqual(
      currentURL(),
      "/t/development-mode-super-slow/2179",
      "redirects to selected search result url"
    );
  });

  test("initial options - search history - no context", async function (assert) {
    await visit("/");
    await click("#search-button");

    assert
      .dom(".search-menu .search-menu-recent li:nth-of-type(1) .search-link")
      .hasText("yellow", "shows first recent search");

    assert
      .dom(".search-menu .search-menu-recent li:nth-of-type(2) .search-link")
      .hasText("blue", "shows second recent search");

    await click(
      ".search-menu .search-menu-recent li:nth-of-type(1) .search-link"
    );

    assert.dom("input#search-term").hasValue("yellow");
  });

  test("initial options - overriding behavior with addSearchMenuAssistantSelectCallback", async function (assert) {
    await visit("/");
    await click("#search-button");

    withPluginApi("1.20.0", (api) => {
      api.addSearchMenuAssistantSelectCallback((args) => {
        if (args.usage === "recent-search") {
          args.searchTermChanged("hijacked!");
          return false;
        }

        return true;
      });
    });

    await click(
      ".search-menu .search-menu-recent li:nth-of-type(1) .search-link"
    );

    assert.dom("#search-term").hasValue("hijacked!");
  });

  test("initial options - search history - category context", async function (assert) {
    await visit("/c/bug");
    await click("#search-button");

    assert
      .dom(".search-menu .search-menu-recent li:nth-of-type(1) .search-link")
      .exists("shows search history");
  });

  test("initial options - search history - user context", async function (assert) {
    await visit("/u/eviltrout");
    await click("#search-button");

    assert
      .dom(".search-menu .search-menu-recent li:nth-of-type(1) .search-link")
      .exists("shows search history");
  });
});

acceptance("Search - with tagging enabled", function (needs) {
  needs.user();
  needs.settings({ tagging_enabled: true });
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
  });

  test("topic results - displays tags", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");
    await triggerKeyEvent("#search-term", "keyup", 13);

    assert
      .dom(".search-menu .results ul li:nth-of-type(1) .discourse-tags")
      .hasText("devslow", "tags displayed in search results");
  });

  test("initial options - topic search scope - selecting a tag defaults to searching 'in all topics'", async function (assert) {
    await visit("/t/internationalization-localization/280/1");
    await click("#search-button");
    await fillIn("#search-term", "#dev");
    await click(
      ".search-menu .results .search-menu-assistant .search-menu-assistant-item:nth-child(1)"
    );
    assert
      .dom(".search-input .btn.search-context")
      .doesNotExist("'in this topic' button is not shown");
  });

  test("initial results - displays tag shortcuts", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dude #monk");
    const firstItem =
      ".search-menu .results ul.search-menu-assistant .search-link";

    assert.dom(firstItem).exists();
    assert.dom(`${firstItem} .search-item-tag`).hasText("monkey");
  });

  test("initial options - search history - tag context", async function (assert) {
    await visit("/tags/c/bug/dev");
    await click("#search-button");

    assert
      .dom(".search-menu .search-menu-recent li:nth-of-type(1) .search-link")
      .exists("shows search history");
  });

  test("initial options - tag search scope - shows category / tag combination shortcut when both are present", async function (assert) {
    await visit("/tags/c/bug/dev");
    await click("#search-button");

    assert
      .dom(
        ".search-menu .results ul.search-menu-assistant .badge-category__name"
      )
      .hasText("bug", "Category is displayed");

    assert
      .dom(".search-menu .results ul.search-menu-assistant .search-item-tag")
      .hasText("dev", "Tag is displayed");
  });

  test("initial options - tag and category search scope - updates tag / category combination search suggestion when typing", async function (assert) {
    await visit("/tags/c/bug/dev");
    await click("#search-button");
    await fillIn("#search-term", "foo bar");

    assert
      .dom(".search-menu .results ul.search-menu-assistant .search-item-prefix")
      .hasText("foo bar", "Input is applied to search query");

    assert
      .dom(
        ".search-menu .results ul.search-menu-assistant .badge-category__name"
      )
      .hasText("bug");

    assert
      .dom(".search-menu .results ul.search-menu-assistant .search-item-tag")
      .hasText("dev", "Tag is displayed");
  });

  test("initial options - search history - tag intersection context", async function (assert) {
    await visit("/tags/intersection/dev/foo");
    await click("#search-button");

    assert
      .dom(".search-menu .search-menu-recent li:nth-of-type(1) .search-link")
      .exists("shows search history");
  });

  test("initial options - tag intersection search scope - shows tag combination shortcut when visiting tag intersection", async function (assert) {
    await visit("/tags/intersection/dev/foo");
    await click("#search-button");

    assert
      .dom(".search-menu .results ul.search-menu-assistant .search-item-tag")
      .hasText("tags:dev+foo", "Tags are displayed");
  });

  test("initial options - tag intersection search scope - updates tag intersection search suggestion when typing", async function (assert) {
    await visit("/tags/intersection/dev/foo");
    await click("#search-button");
    await fillIn("#search-term", "foo bar");

    assert
      .dom(".search-menu .results ul.search-menu-assistant .search-item-prefix")
      .hasText("foo bar", "Input is applied to search query");

    assert
      .dom(".search-menu .results ul.search-menu-assistant .search-item-tag")
      .hasText("tags:dev+foo", "Tags are displayed");
  });
});

acceptance("Search - assistant", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/t/2179.json", () => {
      return helper.response({});
    });
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

    server.get("/u/search/users", () => {
      return helper.response({
        users: [
          {
            username: "TeaMoe",
            name: "TeaMoe Full",
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

    server.post("/search/click", () => {
      return helper.response({ success: "OK" });
    });
  });

  test("initial options - shows category shortcuts when typing #", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "#");

    assert
      .dom(
        ".search-menu .results ul.search-menu-assistant .search-link .badge-category__name"
      )
      .hasText("support");
  });

  test("initial options - shows in: shortcuts", async function (assert) {
    await visit("/");
    await click("#search-button");
    const firstTarget =
      ".search-menu .results ul.search-menu-assistant .search-link";

    await fillIn("#search-term", "in:");
    assert
      .dom(`${firstTarget} .search-item-slug`)
      .hasText("in:title", "keyword is present in suggestion");

    await fillIn("#search-term", "sam in:");
    assert
      .dom(`${firstTarget} .search-item-prefix`)
      .hasText("sam", "term is present in suggestion");
    assert
      .dom(`${firstTarget} .search-item-slug`)
      .hasText("in:title", "keyword is present in suggestion");

    await fillIn("#search-term", "in:mess");
    assert.dom(firstTarget).hasText("in:messages");
  });

  test("initial options - user search scope - shows users when typing @", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "@");
    assert
      .dom(
        ".search-menu .results ul.search-menu-assistant .search-item-user .username"
      )
      .hasText("TeaMoe");

    const username = document
      .querySelector(
        ".search-menu .results ul.search-menu-assistant .search-item-user .username"
      )
      .innerText.trim();

    await click(
      ".search-menu .results ul.search-menu-assistant .search-item-user"
    );

    assert.dom("#search-term").hasValue(`@${username}`);
  });

  test("initial options - topic search scope - selecting a tag defaults to searching 'in all topics'", async function (assert) {
    await visit("/t/internationalization-localization/280/1");
    await click("#search-button");
    await fillIn("#search-term", "@");
    await click(
      ".search-menu .results .search-menu-assistant .search-menu-assistant-item:nth-child(1)"
    );

    assert
      .dom(".search-input .btn.search-context")
      .doesNotExist("'in this topic' button is not shown");
  });

  test("initial options - search history - topic context", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#search-button");

    assert
      .dom(".search-menu .search-menu-recent li:nth-of-type(1) .search-link")
      .exists("shows search history");
  });

  test("initial options - search history - private message context", async function (assert) {
    await visit("/u/charlie/messages");
    await click("#search-button");

    assert
      .dom(".search-menu .search-menu-recent")
      .doesNotExist("does not show search history");
  });

  test("initial options - private message search scope - shows 'in messages' button when in an inbox", async function (assert) {
    await visit("/u/charlie/messages");
    await click("#search-button");

    assert.dom(".btn.search-context").exists("shows the button");

    await fillIn("#search-term", "");
    focus("input#search-term");
    await triggerKeyEvent("input#search-term", "keyup", "Backspace");

    assert.dom(".btn.search-context").doesNotExist("removes the button");

    await clickOutside();
    await click("#search-button");
    assert
      .dom(".btn.search-context")
      .exists("shows the button when reinvoking search");

    await fillIn("#search-term", "emoji");
    focus("input#search-term");
    await triggerKeyEvent("#search-term", "keyup", "Enter");

    assert
      .dom(".search-menu .search-result-topic")
      .exists({ count: 1 }, "passes the PM search context to the search query");
  });

  test("topic results - updates search term when selecting an initial category option", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "sam #");

    const firstCategory =
      ".search-menu .results ul.search-menu-assistant .search-link";
    const firstCategoryName = document.querySelector(
      `${firstCategory} .badge-category__name`
    ).innerText;

    await click(`${firstCategory} .badge-category__name`);

    assert.dom("#search-term").hasValue(`sam #${firstCategoryName}`);
  });

  test("topic results - soft loads the topic results after closing the search menu", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "Development mode");

    // navigate to topic and close search menu
    const firstTopicResult = ".search-menu .results .search-result-topic a";
    await click(firstTopicResult);

    // reopen search menu and previous search results are present
    await click("#search-button");
    assert.dom(firstTopicResult).exists();
  });
});
