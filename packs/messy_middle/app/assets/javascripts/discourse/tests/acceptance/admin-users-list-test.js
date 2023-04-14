import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import I18n from "I18n";
import { test } from "qunit";

acceptance("Admin - Users List", function (needs) {
  needs.user();

  test("lists users", async function (assert) {
    await visit("/admin/users/list/active");

    assert.ok(exists(".users-list .user"));
    assert.ok(!exists(".user:nth-of-type(1) .email small"), "escapes email");
  });

  test("searching users with no matches", async function (assert) {
    await visit("/admin/users/list/active");

    await fillIn(".controls.username input", "doesntexist");

    assert.equal(
      query(".users-list-container").innerText,
      I18n.t("search.no_results")
    );
  });

  test("sorts users", async function (assert) {
    await visit("/admin/users/list/active");

    assert.ok(exists(".users-list .user"));

    await click(".users-list .sortable:nth-child(1)");

    assert.ok(
      query(".users-list .user:nth-child(1) .username").innerText.includes(
        "eviltrout"
      ),
      "list should be sorted by username"
    );

    await click(".users-list .sortable:nth-child(1)");

    assert.ok(
      query(".users-list .user:nth-child(1) .username").innerText.includes(
        "discobot"
      ),
      "list should be sorted ascending by username"
    );
  });

  test("toggles email visibility", async function (assert) {
    await visit("/admin/users/list/active");

    assert.ok(exists(".users-list .user"));

    await click(".show-emails");

    assert.strictEqual(
      query(".users-list .user:nth-child(1) .email").innerText,
      "<small>eviltrout@example.com</small>",
      "shows the emails"
    );

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
    const activeTitle = I18n.t("admin.users.titles.active");
    const suspectTitle = I18n.t("admin.users.titles.new");

    await visit("/admin/users/list/active");

    assert.strictEqual(query(".admin-title h2").innerText, activeTitle);
    assert.ok(
      query(".users-list .user:nth-child(1) .username").innerText.includes(
        activeUser
      )
    );

    await click('a[href="/admin/users/list/new"]');

    assert.strictEqual(query(".admin-title h2").innerText, suspectTitle);
    assert.ok(
      query(".users-list .user:nth-child(1) .username").innerText.includes(
        suspectUser
      )
    );

    await click(".users-list .sortable:nth-child(4)");

    assert.strictEqual(query(".admin-title h2").innerText, suspectTitle);
    assert.ok(
      query(".users-list .user:nth-child(1) .username").innerText.includes(
        suspectUser
      )
    );

    await click('a[href="/admin/users/list/active"]');

    assert.strictEqual(query(".admin-title h2").innerText, activeTitle);
    assert.ok(
      query(".users-list .user:nth-child(1) .username").innerText.includes(
        activeUser
      )
    );
  });
});
