import {
  click,
  currentURL,
  fillIn,
  settled,
  triggerEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import stubIntersectionObserver from "discourse/tests/helpers/stub-intersection-observer";
import {
  disableLoadMoreObserver,
  enableLoadMoreObserver,
} from "discourse/ui-kit/d-load-more";
import { i18n } from "discourse-i18n";

acceptance("Admin - Users List", function (needs) {
  needs.user();

  let lastActivationFilter;
  let lastBotShowEmails;
  let lastBotQuery;

  needs.pretender((server, helper) => {
    server.get("/admin/users/list/bots.json", (request) => {
      lastBotShowEmails = request.queryParams.show_emails;
      lastBotQuery = request.queryParams;
      return helper.response([
        {
          id: -100,
          username: "helper_bot",
          post_count: 12,
          bot_creator: {
            username: "sam",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/s/3be4f8/{size}.png",
            url: "/admin/users/2/sam",
          },
          sources: [
            { label: "<strong>Helper</strong>", url: "/admin/bots/helper" },
            { label: "Support", url: "/forum/admin/bots/support" },
          ],
        },
        {
          id: -101,
          username: "historical_bot",
          sources: [{ label: "<em>Historical integration</em>" }],
        },
        {
          id: -106,
          username: "paused_bot",
          sources: [{ label: "Paused agent", note: "Integration disabled" }],
          bot_inactive: true,
        },
        { id: -102, username: "unknown_bot" },
        { id: -103, username: "unattributed_bot", sources: [] },
        {
          id: -105,
          username: "manual_bot",
          bot_creator: {
            username: "sam",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/s/3be4f8/{size}.png",
            url: "/admin/users/2/sam",
          },
        },
        {
          id: -106,
          username: "escaped_creator_bot",
          sources: [],
          bot_creator: {
            username: "<em>sam</em>",
            url: "/forum/admin/users/2/sam",
          },
        },
        {
          id: -104,
          username: "long_name_bot",
          sources: [
            {
              label: "An agent with a very very very long name dot com",
              url: "/admin/bots/long-name",
            },
          ],
        },
      ]);
    });

    for (const tab of ["staff", "staged"]) {
      server.get(`/admin/users/list/${tab}.json`, () =>
        helper.response([
          {
            id: 5,
            username: "sam",
            sources: [{ label: "Integration", url: "/admin/bots/helper" }],
          },
        ])
      );
    }

    server.get("/admin/users/list/silenced.json", () =>
      helper.response([
        {
          id: 2,
          username: "kris",
          email: "<small>kris@example.com</small>",
          silenced_at: "2020-01-01T00:00:00.000Z",
          silence_reason: "<strong>spam</strong>",
        },
      ])
    );

    server.get("/admin/users/list/suspended.json", () =>
      helper.response([
        {
          id: 4,
          username: "ben",
          email: "<small>ben@example.com</small>",
          suspended_at: "2020-01-01T00:00:00.000Z",
          suspend_reason: "<strong>spam</strong>",
        },
      ])
    );

    server.get("/admin/users/list/new.json", (request) => {
      lastActivationFilter = request.queryParams.activation;

      const users = [
        { id: 2, username: "sam", active: true },
        { id: 3, username: "notactivated", active: false },
      ];

      if (request.queryParams.activation === "not_activated") {
        return helper.response(users.filter((user) => !user.active));
      }

      return helper.response(users);
    });
  });

  test("shows Bots without Groups in the users tabs", async function (assert) {
    await visit("/admin/users/list/active");

    assert
      .dom(".admin-users-tabs__groups")
      .doesNotExist("omits the Groups tab");
    assert
      .dom(".admin-users-tabs__bots a")
      .hasText(i18n("admin.users.nav.bots"), "labels the tab Bots");

    await click(".admin-users-tabs__bots a");

    assert.strictEqual(
      currentURL(),
      "/admin/users/list/bots",
      "opens the bots list"
    );
    assert
      .dom(".admin-users-tabs__bots a")
      .hasClass("active", "selects the Bots tab");
    assert
      .dom(".users-list .user .username")
      .includesText("helper_bot", "lists bot accounts");
    assert
      .dom(".d-filter-controls__dropdown")
      .doesNotExist("does not offer a human account filter");
  });

  test("shows linked bot sources with escaped labels", async function (assert) {
    await visit("/admin/users/list/bots");

    assert
      .dom(".admin-users-list__source-header")
      .hasText(i18n("admin.users.source"), "labels the Source column");
    assert
      .dom(
        '[data-user-id="-100"] .admin-users-list__source .directory-table__label'
      )
      .hasText(i18n("admin.users.source"), "labels the source on mobile");
    assert
      .dom('[data-user-id="-100"] .admin-users-list__source a')
      .exists({ count: 2 }, "renders links for each source");
    assert
      .dom(
        '[data-user-id="-100"] .admin-users-list__source a[href="/admin/bots/helper"]'
      )
      .hasText("<strong>Helper</strong>", "escapes the source label")
      .hasAttribute(
        "href",
        "/admin/bots/helper",
        "uses the internal source URL"
      );
    assert
      .dom('[data-user-id="-100"] .admin-users-list__source strong')
      .doesNotExist("does not trust source HTML");
    assert
      .dom(
        '[data-user-id="-100"] .admin-users-list__source a[href="/forum/admin/bots/support"]'
      )
      .hasText("Support", "preserves a source URL that includes the base path");
  });

  test("shows creator attribution when a bot has no configured source", async function (assert) {
    await visit("/admin/users/list/bots");

    const label = i18n("admin.users.bots.created_by", { username: "sam" });
    assert
      .dom('[data-user-id="-105"] .admin-users-list__source a img.avatar')
      .exists("shows the creator's avatar");
    assert
      .dom('[data-user-id="-105"] .admin-users-list__source a')
      .hasText("sam", "identifies the creator by username")
      .hasAttribute(
        "aria-label",
        label,
        "explains the creator relationship accessibly"
      )
      .hasAttribute(
        "href",
        "/admin/users/2/sam",
        "links to the creator's admin page"
      );
    assert
      .dom('[data-user-id="-105"] .admin-users-list__source-item')
      .hasAttribute("title", label, "preserves the full attribution on hover");
    assert
      .dom(
        '[data-user-id="-100"] .admin-users-list__source a[href="/admin/users/2/sam"]'
      )
      .doesNotExist("a configured source takes precedence over the creator");
  });

  test("escapes creator names and preserves subfolder links", async function (assert) {
    await visit("/admin/users/list/bots");

    assert
      .dom('[data-user-id="-106"] .admin-users-list__source a')
      .hasText("<em>sam</em>", "escapes the creator name")
      .hasAttribute(
        "href",
        "/forum/admin/users/2/sam",
        "preserves the supplied base path"
      );
    assert
      .dom('[data-user-id="-106"] .admin-users-list__source em')
      .doesNotExist("does not interpret creator names as HTML");
  });

  test("preserves the full source name when visually truncated", async function (assert) {
    await visit("/admin/users/list/bots");

    const label = "An agent with a very very very long name dot com";
    assert
      .dom('[data-user-id="-104"] .admin-users-list__source-item a')
      .hasAttribute("title", label, "reveals the full name on hover")
      .hasText(label, "retains the full accessible link text")
      .hasAttribute(
        "href",
        "/admin/bots/long-name",
        "preserves the destination"
      );
  });

  test("shows historical bot sources without links", async function (assert) {
    await visit("/admin/users/list/bots");

    assert
      .dom(
        '[data-user-id="-101"] .admin-users-list__source .directory-table__value'
      )
      .hasText(
        "<em>Historical integration</em>",
        "escapes a text-only source label"
      );
    assert
      .dom(
        '[data-user-id="-101"] .admin-users-list__source a, [data-user-id="-101"] .admin-users-list__source em'
      )
      .doesNotExist(
        "does not add a link or trust HTML for a historical source"
      );
  });

  test("shows a source note in a tooltip", async function (assert) {
    await visit("/admin/users/list/bots");

    assert
      .dom('[data-user-id="-106"] .admin-users-list__source-label')
      .hasText("Paused agent", "the label is shown as is");

    await triggerEvent(
      '[data-user-id="-106"] .admin-users-list__source-label',
      "pointermove"
    );
    assert
      .dom(".fk-d-tooltip__content")
      .hasText("Integration disabled", "the note is shown in a tooltip");
    assert
      .dom('[data-user-id="-106"]')
      .hasClass(
        "not-activated",
        "an inactive bot is dimmed like a disabled one"
      );
  });

  test("shows a fallback for missing or empty bot sources", async function (assert) {
    await visit("/admin/users/list/bots");

    for (const id of [-102, -103]) {
      assert
        .dom(
          `[data-user-id="${id}"] .admin-users-list__source .directory-table__value`
        )
        .hasText("—", "uses an em dash when no sources are available");
      assert
        .dom(`[data-user-id="${id}"] .admin-users-list__source a`)
        .doesNotExist("does not link an unknown source");
    }
  });

  test("only shows the Source column on the Bots tab", async function (assert) {
    await visit("/admin/users/list/bots");

    assert
      .dom(".admin-users-list__source-header")
      .exists("shows the header on the Bots tab");

    for (const tab of [
      "active",
      "new",
      "staff",
      "suspended",
      "silenced",
      "staged",
    ]) {
      await visit(`/admin/users/list/${tab}`);

      assert
        .dom(".admin-users-list__source-header, .admin-users-list__source")
        .doesNotExist(`omits the Source column on the ${tab} tab`);
    }
  });

  test("shows posts created on Bots and sorts activity columns in both directions", async function (assert) {
    await visit("/admin/users/list/bots");

    assert
      .dom(
        '[data-user-id="-100"] .admin-users-list__posts-created .directory-table__value'
      )
      .hasText("12", "shows the bot's post count");
    assert
      .dom("#table-header-toggle-posts")
      .hasText(i18n("admin.user.post_count"), "labels the count column");

    for (const field of ["topics_viewed", "posts_read", "posts", "created"]) {
      const header = `#table-header-toggle-${field}`;
      await click(header);
      assert.strictEqual(
        lastBotQuery.order,
        field,
        `requests sorting by ${field}`
      );
      assert.false(
        Boolean(lastBotQuery.asc),
        `${field} initially sorts descending`
      );
      assert
        .dom(header)
        .hasAttribute("aria-pressed", "true", "announces descending order");

      await click(header);
      assert.strictEqual(
        lastBotQuery.asc,
        "true",
        `${field} can sort ascending`
      );
      assert
        .dom(header)
        .hasAttribute("aria-pressed", "mixed", "announces ascending order");
    }

    await visit("/admin/users/list/active");
    assert
      .dom("#table-header-toggle-posts, .admin-users-list__posts-created")
      .doesNotExist("the added column is specific to Bots");
  });

  test("hides human activity columns on Bots and keeps the grid aligned", async function (assert) {
    this.siteSettings.must_approve_users = false;

    await visit("/admin/users/list/active");
    await click(".admin-users__subheader-show-emails");
    await visit("/admin/users/list/bots");

    assert
      .dom(".admin-users-list__source-header")
      .exists("admins retain the Source header");
    assert
      .dom(".admin-users-list__source")
      .exists({ count: 8 }, "admins retain a Source cell for every bot");
    assert
      .dom(".users-list")
      .hasAttribute(
        "style",
        /repeat\(7,/,
        "accounts for Source and the two hidden columns"
      );

    assert
      .dom("#table-header-toggle-last_emailed, .users-list .last-emailed")
      .doesNotExist("omits the Last Emailed header and cells on Bots");

    assert
      .dom("#table-header-toggle-read_time, .users-list .time-read")
      .doesNotExist("omits the Read Time header and cells on Bots");

    assert
      .dom(
        ".admin-users__subheader-show-emails, .admin-users__subheader-hide-emails"
      )
      .doesNotExist(
        "omits email actions on Bots even after revealing emails elsewhere"
      );
    assert
      .dom("#table-header-toggle-email")
      .isNotVisible("keeps the email header hidden on Bots");
    assert
      .dom(".users-list .email:not(.hidden)")
      .doesNotExist("keeps all email cells hidden on Bots");
    assert.strictEqual(
      lastBotShowEmails,
      "false",
      "does not request bot email addresses"
    );

    this.siteSettings.must_approve_users = true;
    await settled();

    assert
      .dom(".users-list")
      .hasAttribute("style", /repeat\(8,/, "adds the approval grid column");

    await visit("/admin/users/list/active");

    assert
      .dom(".admin-users__subheader-hide-emails")
      .exists("preserves email visibility on human user lists");
    assert
      .dom("#table-header-toggle-last_emailed")
      .exists("keeps the Last Emailed header on other tabs");
    assert
      .dom(".users-list .last-emailed")
      .exists("keeps the Last Emailed cells on other tabs");

    assert
      .dom("#table-header-toggle-read_time")
      .exists("keeps the Read Time header on other tabs");
    assert
      .dom(".users-list .time-read")
      .exists("keeps the Read Time cells on other tabs");

    assert
      .dom(".users-list")
      .hasAttribute(
        "style",
        /repeat\(9,/,
        "restores the standard columns on other tabs"
      );
  });

  test("lists users", async function (assert) {
    await visit("/admin/users/list/active");

    assert.dom(".users-list .user").exists();
    assert
      .dom(".user:nth-of-type(1) .email small")
      .doesNotExist("escapes email");
  });

  test("searching users with no matches", async function (assert) {
    await visit("/admin/users/list/active");

    await fillIn(".d-filter-controls__input", "doesntexist");

    assert
      .dom(".d-filter-controls__no-results p")
      .hasText(i18n("search.no_results"));
  });

  test("sorts users", async function (assert) {
    await visit("/admin/users/list/active");

    assert.dom(".users-list .user").exists();

    await click(
      ".users-list .directory-table__column-header--username.sortable"
    );

    assert
      .dom(".users-list .user:nth-child(1) .username")
      .includesText("eviltrout", "list should be sorted by username");

    await click(
      ".users-list .directory-table__column-header--username.sortable"
    );

    assert
      .dom(".users-list .user:nth-child(1) .username")
      .includesText("discobot", "list should be sorted ascending by username");
  });

  test("toggles email visibility", async function (assert) {
    await visit("/admin/users/list/active");

    assert.dom(".users-list .user").exists();

    await click(".admin-users__subheader-show-emails");

    assert
      .dom(".users-list .user:nth-child(1) .email")
      .hasText("<small>eviltrout@example.com</small>", "shows the emails");

    await click(".admin-users__subheader-hide-emails");

    assert
      .dom(".users-list .user:nth-child(1) .email .directory-table__value")
      .hasNoText("hides the emails");
  });

  test("switching tabs", async function (assert) {
    const activeUser = "eviltrout";
    const suspectUser = "sam";
    const activeTitle = i18n("admin.users.titles.active");
    const suspectTitle = i18n("admin.users.titles.new");

    await visit("/admin/users/list/active");

    assert.dom(".d-page-subheader__title").hasText(activeTitle);
    assert
      .dom(".users-list .user:nth-child(1) .username")
      .includesText(activeUser);

    await click('a[href="/admin/users/list/new"]');

    assert.dom(".d-page-subheader__title").hasText(suspectTitle);
    assert
      .dom(".users-list .user:nth-child(1) .username")
      .includesText(suspectUser);

    await click(".users-list .sortable:nth-child(4)");

    assert.dom(".d-page-subheader__title").hasText(suspectTitle);
    assert
      .dom(".users-list .user:nth-child(1) .username")
      .includesText(suspectUser);

    await click('a[href="/admin/users/list/active"]');

    assert.dom(".d-page-subheader__title").hasText(activeTitle);
    assert
      .dom(".users-list .user:nth-child(1) .username")
      .includesText(activeUser);

    await click('a[href="/admin/users/list/silenced"]');
    assert.dom(".silence_reason").hasAttribute("title", "spam");
    assert
      .dom(".silence_reason .directory-table__value")
      .hasHtml("<strong>spam</strong>");
  });

  test("shows the suspend reason on the suspended tab", async function (assert) {
    await visit("/admin/users/list/suspended");

    assert.dom(".suspend_reason").hasAttribute("title", "spam");
    assert
      .dom(".suspend_reason .directory-table__value")
      .hasHtml("<strong>spam</strong>");
  });

  test("activation filter is only shown on the new tab", async function (assert) {
    await visit("/admin/users/list/active");
    assert.dom(".d-filter-controls__dropdown").doesNotExist();

    await visit("/admin/users/list/new");
    assert.dom(".d-filter-controls__dropdown").exists();
  });

  test("filters the new tab by activation status", async function (assert) {
    await visit("/admin/users/list/new");

    assert.dom(".users-list .user").exists({ count: 2 });

    await fillIn(".d-filter-controls__dropdown", "not_activated");

    assert.strictEqual(
      lastActivationFilter,
      "not_activated",
      "sends the activation filter to the server"
    );
    assert.dom(".users-list .user").exists({ count: 1 });
    assert
      .dom(".users-list .user:nth-child(1) .username")
      .includesText("notactivated");
    assert.true(
      currentURL().includes("activation=not_activated"),
      "stores the activation filter in the URL"
    );

    await visit(
      "/admin/users/list/new?username=sam&activation=not_activated&order=username"
    );
    await click(".d-filter-controls__reset");

    assert.dom(".users-list .user").exists({ count: 2 }, "reloads all users");
    assert.strictEqual(
      currentURL(),
      "/admin/users/list/new?order=username",
      "clears both legacy search and activation while preserving sorting"
    );
  });
});

acceptance("Admin - Users List - email permissions", function (needs) {
  needs.user({ admin: false, moderator: true });
  needs.settings({ moderators_view_emails: false });

  test("shows the email action only when moderators can view emails", async function (assert) {
    await visit("/admin/users/list/active");

    assert
      .dom(".admin-users__subheader-show-emails")
      .doesNotExist("hides the unauthorized action");

    this.siteSettings.moderators_view_emails = true;
    await visit("/admin/users/list/new");

    assert
      .dom(".admin-users__subheader-show-emails")
      .exists("shows the permitted action");
  });
});

acceptance("Admin - Users List - pagination", function (needs) {
  needs.user();

  let lastRequest;
  let requestCount;
  let users;

  needs.pretender((server, helper) => {
    requestCount = 0;
    users = [{ id: 2, username: "sam" }];
    server.get("/admin/users/list/active.json", (request) => {
      requestCount++;
      lastRequest = request.queryParams;
      return helper.response(users);
    });
  });

  test("loads more users only after a full page", async function (assert) {
    enableLoadMoreObserver();
    const observations = stubIntersectionObserver();
    const scrollToBottom = () =>
      observations
        .findLast(({ element }) =>
          element.matches(".users-list-container > .load-more-sentinel")
        )
        .trigger();

    try {
      await visit("/admin/users/list/active");
      await scrollToBottom();

      assert.strictEqual(requestCount, 1, "fetches the complete list once");

      const pageSize = 100;
      users = Array.from({ length: pageSize }, (_, index) => ({
        id: index + 1,
        username: `user${index + 1}`,
      }));
      await click(
        ".users-list .directory-table__column-header--username.sortable"
      );

      users = [{ id: pageSize + 1, username: "lastuser" }];
      await scrollToBottom();

      assert.strictEqual(
        lastRequest.page,
        "2",
        "loads the next page after a full page"
      );
      assert
        .dom(".users-list .user")
        .exists({ count: pageSize + 1 }, "appends the remaining user");

      await scrollToBottom();

      assert.strictEqual(requestCount, 3, "stops after the final short page");
    } finally {
      disableLoadMoreObserver();
    }
  });
});

acceptance("Admin - Users List - moderator bots", function (needs) {
  needs.user({ admin: false, moderator: true });

  needs.pretender((server, helper) => {
    server.get("/admin/users/list/bots.json", () =>
      helper.response([{ id: -100, username: "helper_bot" }])
    );
  });

  test("omits the admin-only Source column and keeps the grid aligned", async function (assert) {
    this.siteSettings.must_approve_users = false;

    await visit("/admin/users/list/bots");

    assert
      .dom('.users-list [data-user-id="-100"] .username')
      .includesText("helper_bot", "moderators can still list bot accounts");
    assert
      .dom(".admin-users-list__source-header, .admin-users-list__source")
      .doesNotExist("moderators have no Source header or cells");
    assert
      .dom(".users-list")
      .hasAttribute(
        "style",
        /repeat\(6,/,
        "does not reserve a Source grid column"
      );

    this.siteSettings.must_approve_users = true;
    await settled();

    assert
      .dom(".users-list")
      .hasAttribute(
        "style",
        /repeat\(7,/,
        "adds only the approval grid column"
      );
    assert
      .dom(".admin-users-list__source-header, .admin-users-list__source")
      .doesNotExist("approval does not expose the admin-only Source column");
  });
});

acceptance("Admin - Users List - staff account types", function (needs) {
  needs.user();

  let lastRequest;
  let requestCount;

  needs.pretender((server, helper) => {
    requestCount = 0;
    server.get("/admin/users/list/staff.json", (request) => {
      requestCount++;
      lastRequest = request.queryParams;
      return helper.response(
        lastRequest.account_type === "bot" && !lastRequest.filter
          ? []
          : [{ id: 2, username: "sam" }]
      );
    });
  });

  test("selects account types and resets to human accounts", async function (assert) {
    await visit("/admin/users/list/staff");

    assert
      .dom(".d-filter-controls__dropdown")
      .hasValue("human", "defaults to humans");
    assert.strictEqual(
      lastRequest.account_type,
      "human",
      "requests human accounts"
    );

    await fillIn(".d-filter-controls__dropdown", "bot");

    assert.strictEqual(
      lastRequest.account_type,
      "bot",
      "requests bot accounts"
    );
    assert.true(
      currentURL().includes("account_type=bot"),
      "stores the selection in the URL"
    );
    assert
      .dom(".admin-users-list__no-results")
      .doesNotExist("does not duplicate the filtered empty state");
    assert
      .dom(".d-filter-controls__no-results p")
      .hasText(i18n("search.no_results"), "shows the standard empty message");

    await fillIn(".d-filter-controls__dropdown", "all");

    assert.strictEqual(
      lastRequest.account_type,
      "all",
      "requests all accounts"
    );

    await visit(
      "/admin/users/list/staff?username=sam&filter=sam&account_type=all&order=username"
    );
    await click(".d-filter-controls__reset");

    assert
      .dom(".d-filter-controls__dropdown")
      .hasValue("human", "restores the default selection");
    assert.strictEqual(
      lastRequest.account_type,
      "human",
      "reloads human accounts"
    );
    assert.strictEqual(
      currentURL(),
      "/admin/users/list/staff?order=username",
      "clears all filter parameters while preserving sorting"
    );

    await click(
      ".users-list .directory-table__column-header--username.sortable"
    );

    assert.strictEqual(
      lastRequest.account_type,
      "human",
      "sorting keeps the default account type"
    );
    assert.strictEqual(
      lastRequest.filter,
      "",
      "sorting does not restore the cleared search"
    );
  });

  test("restores URL filters, keeps them when sorting, and clears them between tabs", async function (assert) {
    await visit("/admin/users/list/staff?account_type=bot&filter=sam");

    assert.strictEqual(requestCount, 1, "loads once when entering the route");
    assert
      .dom(".d-filter-controls__dropdown")
      .hasValue("bot", "restores the account type");
    assert
      .dom(".d-filter-controls__input")
      .hasValue("sam", "restores the search");

    for (let clickCount = 1; clickCount <= 4; clickCount++) {
      await click(
        ".users-list .directory-table__column-header--username.sortable"
      );

      assert.strictEqual(
        requestCount,
        clickCount + 1,
        "loads once per sort change"
      );
      assert.strictEqual(
        lastRequest.order,
        "username",
        "requests the selected sort"
      );
      assert.strictEqual(
        lastRequest.account_type,
        "bot",
        "preserves the account type"
      );
      assert.strictEqual(lastRequest.filter, "sam", "preserves the search");
      assert
        .dom(".d-filter-controls__input")
        .hasValue("sam", "keeps the search visible");
      assert.true(
        currentURL().includes("filter=sam"),
        "keeps the search in the URL"
      );
    }

    await fillIn(".d-filter-controls__dropdown", "all");

    assert.strictEqual(
      lastRequest.filter,
      "sam",
      "keeps the search when changing account type"
    );

    await click(".admin-users-tabs__new a");

    assert
      .dom(".d-filter-controls__dropdown")
      .hasValue("all", "shows the activation filter");

    await click(".admin-users-tabs__staff a");

    assert
      .dom(".d-filter-controls__dropdown")
      .hasValue("human", "returns to human accounts");
    assert.dom(".d-filter-controls__input").hasValue("", "clears the search");
  });
});

acceptance("Admin - Users List - bulk search", function (needs) {
  needs.user();

  let lastFilter;

  needs.pretender((server, helper) => {
    const respond = (request) => {
      lastFilter = request.queryParams.filter;

      const users = [
        { id: 2, username: "sam" },
        { id: 3, username: "bob" },
      ];

      if (!lastFilter) {
        return helper.response(users);
      }

      const terms = lastFilter.split(/[,\s]+/).filter(Boolean);
      return helper.response(
        users.filter((user) =>
          terms.some((term) => user.username.includes(term))
        )
      );
    };

    server.get("/admin/users/list/active.json", respond);
    server.get("/admin/users/list/new.json", respond);
  });

  test("searches multiple users at once and reflects the search in the URL", async function (assert) {
    await visit("/admin/users/list/active");

    await fillIn(".d-filter-controls__input", "sam,bob");

    assert.strictEqual(
      lastFilter,
      "sam,bob",
      "sends the whole list to the server"
    );
    assert.dom(".users-list .user").exists({ count: 2 });
    assert.true(
      decodeURIComponent(currentURL()).includes("filter=sam,bob"),
      "reflects the search in the URL"
    );
    assert
      .dom(".d-filter-controls__input")
      .isFocused("keeps focus while the URL updates");

    for (let clickCount = 0; clickCount < 2; clickCount++) {
      await click(
        ".users-list .directory-table__column-header--username.sortable"
      );

      assert.strictEqual(
        lastFilter,
        "sam,bob",
        "sorting preserves the typed search"
      );
      assert
        .dom(".d-filter-controls__input")
        .hasValue("sam,bob", "keeps the typed search visible");
      assert.true(
        decodeURIComponent(currentURL()).includes("filter=sam,bob"),
        "sorting preserves the search URL"
      );
    }

    await fillIn(".d-filter-controls__input", "");

    assert.false(
      currentURL().includes("filter="),
      "clearing the search removes it from the URL"
    );
  });

  test("prefills and applies the search from the URL", async function (assert) {
    await visit("/admin/users/list/active?filter=sam");

    assert.dom(".d-filter-controls__input").hasValue("sam");
    assert.strictEqual(lastFilter, "sam", "sends the filter from the URL");
    assert.dom(".users-list .user").exists({ count: 1 });
  });

  test("prefills the search from the legacy username query param", async function (assert) {
    await visit("/admin/users/list/active?username=sam");

    assert.dom(".d-filter-controls__input").hasValue("sam");
    assert.strictEqual(lastFilter, "sam", "sends the filter from the URL");
  });

  test("clears the search when switching tabs", async function (assert) {
    await visit("/admin/users/list/active");

    await fillIn(".d-filter-controls__input", "sam");
    assert.dom(".users-list .user").exists({ count: 1 });

    await click('a[href="/admin/users/list/new"]');

    assert.dom(".d-filter-controls__input").hasValue("");
    assert.strictEqual(
      lastFilter,
      undefined,
      "does not filter the new tab results"
    );

    await click('a[href="/admin/users/list/active"]');

    assert
      .dom(".d-filter-controls__input")
      .hasValue("", "does not restore the search when returning to the tab");
    assert.false(
      currentURL().includes("filter="),
      "does not restore the search in the URL"
    );
  });
});
