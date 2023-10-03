import {
  acceptance,
  count,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import {
  click,
  fillIn,
  settled,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import I18n from "I18n";
import searchFixtures from "discourse/tests/fixtures/search-fixtures";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";
import { DEFAULT_TYPE_FILTER } from "discourse/widgets/search-menu";

acceptance("Search - Anonymous", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/search/query", (request) => {
      if (request.queryParams.type_filter === DEFAULT_TYPE_FILTER) {
        // posts/topics are not present in the payload by default
        return helper.response({
          users: searchFixtures["search/query"]["users"],
          categories: searchFixtures["search/query"]["categories"],
          tags: searchFixtures["search/query"]["tags"],
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
  });

  test("search", async function (assert) {
    await visit("/");

    await click("#search-button");

    assert.ok(exists("#search-term"), "it shows the search input");
    assert.ok(
      exists(".show-advanced-search"),
      "it shows full page search button"
    );
    assert.ok(
      exists(".search-menu .results ul li.search-random-quick-tip"),
      "shows random quick tip by default"
    );

    await fillIn("#search-term", "dev");

    assert.ok(
      !exists(".search-menu .results ul li.search-random-quick-tip"),
      "quick tip no longer shown"
    );

    assert.strictEqual(
      query(
        ".search-menu .results ul.search-menu-initial-options li:first-child .search-item-slug"
      ).innerText.trim(),
      `dev${I18n.t("search.in_topics_posts")}`,
      "shows topic search as first dropdown item"
    );

    assert.ok(
      exists(".search-menu .search-result-category ul li"),
      "shows matching category results"
    );

    assert.ok(
      exists(".search-menu .search-result-user ul li"),
      "shows matching user results"
    );

    await triggerKeyEvent(".search-menu", "keydown", "ArrowDown");
    await click(document.activeElement);

    assert.ok(
      exists(".search-menu .search-result-topic ul li"),
      "shows topic results"
    );
    assert.ok(
      exists(".search-menu .results ul li .topic-title[data-topic-id]"),
      "topic has data-topic-id"
    );

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

  test("search scope", async function (assert) {
    const contextSelector = ".search-menu .results .search-menu-assistant-item";

    await visit("/tag/important");
    await click("#search-button");

    assert.strictEqual(
      queryAll(contextSelector)[0].firstChild.textContent.trim(),
      `${I18n.t("search.in")} important`,
      "contextual tag search is first available option with no term"
    );

    await fillIn("#search-term", "smth");

    assert.strictEqual(
      queryAll(contextSelector)[1].firstChild.textContent.trim(),
      `smth ${I18n.t("search.in")} important`,
      "tag-scoped search is second available option"
    );

    await visit("/c/bug");
    await click("#search-button");

    assert.strictEqual(
      queryAll(contextSelector)[1].firstChild.textContent.trim(),
      `smth ${I18n.t("search.in")} bug`,
      "category-scoped search is first available option with no search term"
    );

    assert.ok(
      exists(`${contextSelector} span.badge-wrapper`),
      "category badge is a span (i.e. not a link)"
    );

    await visit("/t/internationalization-localization/280");
    await click("#search-button");

    assert.strictEqual(
      queryAll(contextSelector)[1].firstChild.textContent.trim(),
      `smth ${I18n.t("search.in_this_topic")}`,
      "topic-scoped search is first available option with no search term"
    );

    await visit("/u/eviltrout");
    await click("#search-button");

    assert.strictEqual(
      queryAll(contextSelector)[1].firstChild.textContent.trim(),
      `smth ${I18n.t("search.in_posts_by", {
        username: "eviltrout",
      })}`,
      "user-scoped search is first available option with no search term"
    );
  });

  test("search scope for topics", async function (assert) {
    await visit("/t/internationalization-localization/280/1");

    await click("#search-button");

    const firstResult =
      ".search-menu .results .search-menu-assistant-item:first-child";

    assert.strictEqual(
      query(firstResult).textContent.trim(),
      I18n.t("search.in_this_topic"),
      "contextual topic search is first available option with no search term"
    );

    await fillIn("#search-term", "a proper");
    await query("input#search-term").focus();
    await triggerKeyEvent(".search-menu", "keydown", "ArrowDown");
    await triggerKeyEvent(".search-menu", "keydown", "ArrowDown");

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
    assert.strictEqual(query("#search-term").value, "", "clear button works");

    await click(".search-context");

    assert.ok(
      !exists(".search-menu .search-context"),
      "search context indicator is no longer visible"
    );

    await fillIn("#search-term", "dev");
    await query("input#search-term").focus();
    await triggerKeyEvent(".search-menu", "keydown", "ArrowDown");
    await triggerKeyEvent(".search-menu", "keydown", "ArrowDown");
    await click(document.activeElement);

    assert.ok(
      exists(".search-menu .search-context"),
      "search context indicator is visible"
    );

    await fillIn("#search-term", "");
    await query("input#search-term").focus();
    await triggerKeyEvent("input#search-term", "keydown", "Backspace");

    assert.ok(
      !exists(".search-menu .search-context"),
      "backspace resets search context"
    );
  });

  test("topic search scope - keep 'in this topic' filter in full page search", async function (assert) {
    await visit("/t/internationalization-localization/280/1");

    await click("#search-button");

    const contextSelector = ".search-menu .results .search-menu-assistant-item";

    assert.strictEqual(
      queryAll(contextSelector)[0].firstChild.textContent.trim(),
      I18n.t("search.in_this_topic"),
      "contextual topic search is first available option with no search term"
    );

    await fillIn("#search-term", "proper");
    await query("input#search-term").focus();
    await triggerKeyEvent(".search-menu", "keydown", "ArrowDown");
    await triggerKeyEvent(".search-menu", "keydown", "ArrowDown");
    await click(document.activeElement);

    assert.ok(
      exists(".search-menu .search-context"),
      "search context indicator is visible"
    );

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

  test("topic search scope - special case when matching a single user", async function (assert) {
    await visit("/t/internationalization-localization/280/1");

    await click("#search-button");
    await fillIn("#search-term", "@admin");

    assert.strictEqual(count(".search-menu-assistant-item"), 2);

    assert.strictEqual(
      query(
        ".search-menu-assistant-item:first-child .search-item-user .label-suffix"
      ).textContent.trim(),
      I18n.t("search.in_topics_posts"),
      "first result hints at global search"
    );

    assert.strictEqual(
      query(
        ".search-menu-assistant-item:nth-child(2) .search-item-user .label-suffix"
      ).textContent.trim(),
      I18n.t("search.in_this_topic"),
      "second result hints at search within current topic"
    );
  });

  test("Right filters are shown in full page search", async function (assert) {
    const inSelector = selectKit(".select-kit#in");

    await visit("/search?expanded=true");

    await inSelector.expand();

    assert.ok(inSelector.rowByValue("first").exists());
    assert.ok(inSelector.rowByValue("pinned").exists());
    assert.ok(inSelector.rowByValue("wiki").exists());
    assert.ok(inSelector.rowByValue("images").exists());

    assert.notOk(inSelector.rowByValue("unseen").exists());
    assert.notOk(inSelector.rowByValue("posted").exists());
    assert.notOk(inSelector.rowByValue("watching").exists());
    assert.notOk(inSelector.rowByValue("tracking").exists());
    assert.notOk(inSelector.rowByValue("bookmarks").exists());

    assert.notOk(exists(".search-advanced-options .in-likes"));
    assert.notOk(exists(".search-advanced-options .in-private"));
    assert.notOk(exists(".search-advanced-options .in-seen"));
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

  test("Right filters are shown in full page search", async function (assert) {
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

  test("Works with empty result sets", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#search-button");
    await fillIn("#search-term", "plans");
    await query("input#search-term").focus();
    await triggerKeyEvent(".search-menu", "keydown", "ArrowDown");
    await click(document.activeElement);

    assert.notStrictEqual(count(".search-menu .results .item"), 0);

    await fillIn("#search-term", "plans empty");
    await triggerKeyEvent("#search-term", "keydown", 13);

    assert.strictEqual(count(".search-menu .results .item"), 0);
    assert.strictEqual(count(".search-menu .results .no-results"), 1);
  });

  test("search dropdown keyboard navigation", async function (assert) {
    const container = ".search-menu .results";

    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");

    assert.ok(exists(query(`${container} ul li`)), "has a list of items");

    await triggerKeyEvent("#search-term", "keydown", "Enter");
    assert.ok(
      exists(query(`${container} .search-result-topic`)),
      "has topic results"
    );

    await triggerKeyEvent("#search-term", "keydown", "ArrowDown");

    assert.strictEqual(
      document.activeElement.getAttribute("href"),
      query(`${container} li:first-child a`).getAttribute("href"),
      "arrow down selects first element"
    );

    await triggerKeyEvent("#search-term", "keydown", "ArrowDown");

    assert.strictEqual(
      document.activeElement.getAttribute("href"),
      query(`${container} li:nth-child(2) a`).getAttribute("href"),
      "arrow down selects next element"
    );

    await triggerKeyEvent("#search-term", "keydown", "ArrowDown");
    await triggerKeyEvent("#search-term", "keydown", "ArrowDown");
    await triggerKeyEvent("#search-term", "keydown", "ArrowDown");
    await triggerKeyEvent("#search-term", "keydown", "ArrowDown");

    assert.strictEqual(
      document.activeElement.getAttribute("href"),
      "/search?q=dev",
      "arrow down sets focus to more results link"
    );

    await triggerKeyEvent(".search-menu", "keydown", "Escape");
    assert.strictEqual(
      document.activeElement,
      query("#search-button"),
      "Escaping search returns focus to search button"
    );
    assert.ok(!exists(".search-menu:visible"), "Esc removes search dropdown");

    await click("#search-button");
    await triggerKeyEvent(".search-menu", "keydown", "ArrowDown");
    await triggerKeyEvent(".search-menu", "keydown", "ArrowUp");

    assert.strictEqual(
      document.activeElement.tagName.toLowerCase(),
      "input",
      "arrow up sets focus to search term input"
    );

    await triggerKeyEvent(".search-menu", "keydown", "Escape");
    await click("#create-topic");
    await click("#search-button");
    await triggerKeyEvent(".search-menu", "keydown", "ArrowDown");

    const firstLink = query(`${container} li:nth-child(1) a`).getAttribute(
      "href"
    );
    await triggerKeyEvent(".search-menu", "keydown", "A");
    await settled();

    assert.strictEqual(
      query("#reply-control textarea").value,
      `${window.location.origin}${firstLink}`,
      "hitting A when focused on a search result copies link to composer"
    );

    await click("#search-button");
    await triggerKeyEvent("#search-term", "keydown", "Enter");

    assert.ok(
      exists(query(`${container} .search-result-topic`)),
      "has topic results"
    );

    await triggerKeyEvent("#search-term", "keydown", "Enter");

    assert.ok(
      exists(query(`.search-container`)),
      "second Enter hit goes to full page search"
    );
    assert.ok(
      !exists(query(`.search-menu`)),
      "search dropdown is collapsed after second Enter hit"
    );

    // new search launched, Enter key should be reset
    await click("#search-button");
    assert.ok(exists(query(`${container} ul li`)), "has a list of items");
    await triggerKeyEvent("#search-term", "keydown", "Enter");
    assert.ok(exists(query(`.search-menu`)), "search dropdown is visible");
  });

  test("search while composer is open", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".reply");
    await fillIn(".d-editor-input", "a link");
    await click("#search-button");
    await fillIn("#search-term", "dev");

    await triggerKeyEvent("#search-term", "keydown", "Enter");
    await triggerKeyEvent(".search-menu", "keydown", "ArrowDown");
    await triggerKeyEvent("#search-term", "keydown", 65); // maps to lowercase a

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

  test("Shows recent search results", async function (assert) {
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

acceptance("Search - with tagging enabled", function (needs) {
  needs.user();
  needs.settings({ tagging_enabled: true });

  test("displays tags", async function (assert) {
    await visit("/");
    await click("#search-button");
    await fillIn("#search-term", "dev");
    await triggerKeyEvent("#search-term", "keydown", 13);

    assert.strictEqual(
      query(
        ".search-menu .results ul li:nth-of-type(1) .discourse-tags"
      ).textContent.trim(),
      "dev slow",
      "tags displayed in search results"
    );
  });

  test("displays tag shortcuts", async function (assert) {
    await visit("/");

    await click("#search-button");

    await fillIn("#search-term", "dude #monk");
    await triggerKeyEvent("#search-term", "keyup", 51);

    const firstItem =
      ".search-menu .results ul.search-menu-assistant .search-link";
    assert.ok(exists(query(firstItem)));

    const firstTag = query(`${firstItem} .search-item-tag`).textContent.trim();
    assert.strictEqual(firstTag, "monkey");
  });
});

acceptance("Search - assistant", function (needs) {
  needs.user();

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

  test("shows category shortcuts when typing #", async function (assert) {
    await visit("/");

    await click("#search-button");

    await fillIn("#search-term", "#");
    await triggerKeyEvent("#search-term", "keyup", 51);

    const firstCategory =
      ".search-menu .results ul.search-menu-assistant .search-link";
    assert.ok(exists(query(firstCategory)));

    const firstResultSlug = query(
      `${firstCategory} .category-name`
    ).textContent.trim();

    await click(firstCategory);
    assert.strictEqual(query("#search-term").value, `#${firstResultSlug}`);

    await fillIn("#search-term", "sam #");
    await triggerKeyEvent("#search-term", "keyup", 51);

    assert.ok(exists(query(firstCategory)));
    assert.strictEqual(
      query(
        ".search-menu .results ul.search-menu-assistant .search-item-prefix"
      ).innerText,
      "sam"
    );

    await click(firstCategory);
    assert.strictEqual(query("#search-term").value, `sam #${firstResultSlug}`);
  });

  test("Shows category / tag combination shortcut when both are present", async function (assert) {
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

  test("Updates tag / category combination search suggestion when typing", async function (assert) {
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

  test("Shows tag combination shortcut when visiting tag intersection", async function (assert) {
    await visit("/tags/intersection/dev/foo");
    await click("#search-button");

    assert.strictEqual(
      query(".search-menu .results ul.search-menu-assistant .search-item-tag")
        .innerText,
      "tags:dev+foo",
      "Tags are displayed"
    );
  });

  test("Updates tag intersection search suggestion when typing", async function (assert) {
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

  test("shows in: shortcuts", async function (assert) {
    await visit("/");
    await click("#search-button");

    const firstTarget =
      ".search-menu .results ul.search-menu-assistant .search-link .search-item-slug";

    await fillIn("#search-term", "in:");
    await triggerKeyEvent("#search-term", "keyup", 51);
    assert.strictEqual(query(firstTarget).innerText, "in:title");

    await fillIn("#search-term", "sam in:");
    await triggerKeyEvent("#search-term", "keyup", 51);
    assert.strictEqual(query(firstTarget).innerText, "sam in:title");

    await fillIn("#search-term", "in:mess");
    await triggerKeyEvent("#search-term", "keyup", 51);
    assert.strictEqual(query(firstTarget).innerText, "in:messages");
  });

  test("shows users when typing @", async function (assert) {
    await visit("/");

    await click("#search-button");

    await fillIn("#search-term", "@");
    await triggerKeyEvent("#search-term", "keyup", 51);

    const firstUser =
      ".search-menu .results ul.search-menu-assistant .search-item-user";
    const firstUsername = query(firstUser).innerText.trim();
    assert.strictEqual(firstUsername, "TeaMoe");

    await click(query(firstUser));
    assert.strictEqual(query("#search-term").value, `@${firstUsername}`);
  });

  test("shows 'in messages' button when in an inbox", async function (assert) {
    await visit("/u/charlie/messages");
    await click("#search-button");

    assert.ok(exists(".btn.search-context"), "it shows the button");

    await fillIn("#search-term", "");
    await query("input#search-term").focus();
    await triggerKeyEvent("input#search-term", "keydown", "Backspace");

    assert.notOk(exists(".btn.search-context"), "it removes the button");

    await click(".d-header");
    await click("#search-button");
    assert.ok(
      exists(".btn.search-context"),
      "it shows the button when reinvoking search"
    );

    await fillIn("#search-term", "emoji");
    await query("input#search-term").focus();
    await triggerKeyEvent("#search-term", "keydown", "Enter");

    assert.strictEqual(
      count(".search-menu .search-result-topic"),
      1,
      "it passes the PM search context to the search query"
    );
  });
});
