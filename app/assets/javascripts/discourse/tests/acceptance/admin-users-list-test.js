import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Admin - Users List", function (needs) {
  needs.user();

  test("lists users", async function (assert) {
    await visit("/admin/users/list/active");

    assert.dom(".users-list .user").exists();
    assert
      .dom(".user:nth-of-type(1) .email small")
      .doesNotExist("escapes email");
  });

  test("searching users with no matches", async function (assert) {
    await visit("/admin/users/list/active");

    await fillIn(".admin-users-list__controls .username input", "doesntexist");

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

    await click(".show-emails");

    assert
      .dom(".users-list .user:nth-child(1) .email")
      .hasText("<small>eviltrout@example.com</small>", "shows the emails");

    await click(".hide-emails");

    assert.strictEqual(
      query(".users-list .user:nth-child(1) .email .directory-table__value")
        .innerText,
      "",
      "hides the emails"
    );
  });

  test("switching tabs", async function (assert) {
    const activeUser = "eviltrout";
    const suspectUser = "sam";
    const activeTitle = i18n("admin.users.titles.active");
    const suspectTitle = i18n("admin.users.titles.new");

    await visit("/admin/users/list/active");

    assert.dom(".admin-title h2").hasText(activeTitle);
    assert
      .dom(".users-list .user:nth-child(1) .username")
      .includesText(activeUser);

    await click('a[href="/admin/users/list/new"]');

    assert.dom(".admin-title h2").hasText(suspectTitle);
    assert
      .dom(".users-list .user:nth-child(1) .username")
      .includesText(suspectUser);

    await click(".users-list .sortable:nth-child(4)");

    assert.dom(".admin-title h2").hasText(suspectTitle);
    assert
      .dom(".users-list .user:nth-child(1) .username")
      .includesText(suspectUser);

    await click('a[href="/admin/users/list/active"]');

    assert.dom(".admin-title h2").hasText(activeTitle);
    assert
      .dom(".users-list .user:nth-child(1) .username")
      .includesText(activeUser);
  });
});
