import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Admin - Users List", function (needs) {
  needs.user();

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
});
