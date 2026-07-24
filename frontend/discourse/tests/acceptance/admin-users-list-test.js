import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Admin - Users List", function (needs) {
  needs.user();

  let lastActivationFilter;

  needs.pretender((server, helper) => {
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

  test("lists users", async function (assert) {
    await visit("/admin/users/list/active");

    assert.dom(".users-list .user").exists();
    assert
      .dom(".user:nth-of-type(1) .email small")
      .doesNotExist("escapes email");
  });

  test("searching users with no matches", async function (assert) {
    await visit("/admin/users/list/active");

    await fillIn(".admin-users-list__search input", "doesntexist");

    assert.dom(".users-list-container").hasText(i18n("search.no_results"));
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
    assert.dom(".admin-users-list__activation-filter").doesNotExist();

    await visit("/admin/users/list/new");
    assert.dom(".admin-users-list__activation-filter").exists();
  });

  test("filters the new tab by activation status", async function (assert) {
    await visit("/admin/users/list/new");

    assert.dom(".users-list .user").exists({ count: 2 });

    await fillIn(".admin-users-list__activation-filter", "not_activated");

    assert.strictEqual(
      lastActivationFilter,
      "not_activated",
      "sends the activation filter to the server"
    );
    assert.dom(".users-list .user").exists({ count: 1 });
    assert
      .dom(".users-list .user:nth-child(1) .username")
      .includesText("notactivated");
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

    await fillIn(".admin-users-list__search input", "sam,bob");

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
      .dom(".admin-users-list__search input")
      .isFocused("keeps focus while the URL updates");

    await fillIn(".admin-users-list__search input", "");

    assert.false(
      currentURL().includes("filter="),
      "clearing the search removes it from the URL"
    );
  });

  test("prefills and applies the search from the URL", async function (assert) {
    await visit("/admin/users/list/active?filter=sam");

    assert.dom(".admin-users-list__search input").hasValue("sam");
    assert.strictEqual(lastFilter, "sam", "sends the filter from the URL");
    assert.dom(".users-list .user").exists({ count: 1 });
  });

  test("prefills the search from the legacy username query param", async function (assert) {
    await visit("/admin/users/list/active?username=sam");

    assert.dom(".admin-users-list__search input").hasValue("sam");
    assert.strictEqual(lastFilter, "sam", "sends the filter from the URL");
  });

  test("clears the search when switching tabs", async function (assert) {
    await visit("/admin/users/list/active");

    await fillIn(".admin-users-list__search input", "sam");
    assert.dom(".users-list .user").exists({ count: 1 });

    await click('a[href="/admin/users/list/new"]');

    assert.dom(".admin-users-list__search input").hasValue("");
    assert.strictEqual(
      lastFilter,
      undefined,
      "does not filter the new tab results"
    );

    await click('a[href="/admin/users/list/active"]');

    assert
      .dom(".admin-users-list__search input")
      .hasValue("", "does not restore the search when returning to the tab");
    assert.false(
      currentURL().includes("filter="),
      "does not restore the search in the URL"
    );
  });
});
