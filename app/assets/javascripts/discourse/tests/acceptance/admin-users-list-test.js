import { exists } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Admin - Users List", function (needs) {
  needs.user();

  test("lists users", async (assert) => {
    await visit("/admin/users/list/active");

    assert.ok(exists(".users-list .user"));
    assert.ok(!exists(".user:eq(0) .email small"), "escapes email");
  });

  test("sorts users", async (assert) => {
    await visit("/admin/users/list/active");

    assert.ok(exists(".users-list .user"));

    await click(".users-list .sortable:nth-child(1)");

    assert.ok(
      find(".users-list .user:nth-child(1) .username")
        .text()
        .includes("eviltrout"),
      "list should be sorted by username"
    );

    await click(".users-list .sortable:nth-child(1)");

    assert.ok(
      find(".users-list .user:nth-child(1) .username")
        .text()
        .includes("discobot"),
      "list should be sorted ascending by username"
    );
  });

  test("toggles email visibility", async (assert) => {
    await visit("/admin/users/list/active");

    assert.ok(exists(".users-list .user"));

    await click(".show-emails");

    assert.equal(
      find(".users-list .user:nth-child(1) .email").text(),
      "<small>eviltrout@example.com</small>",
      "shows the emails"
    );

    await click(".hide-emails");

    assert.equal(
      find(".users-list .user:nth-child(1) .email").text(),
      "",
      "hides the emails"
    );
  });

  test("switching tabs", async (assert) => {
    const activeUser = "eviltrout";
    const suspectUser = "sam";
    const activeTitle = I18n.t("admin.users.titles.active");
    const suspectTitle = I18n.t("admin.users.titles.new");

    await visit("/admin/users/list/active");

    assert.equal(find(".admin-title h2").text(), activeTitle);
    assert.ok(
      find(".users-list .user:nth-child(1) .username")
        .text()
        .includes(activeUser)
    );

    await click('a[href="/admin/users/list/new"]');

    assert.equal(find(".admin-title h2").text(), suspectTitle);
    assert.ok(
      find(".users-list .user:nth-child(1) .username")
        .text()
        .includes(suspectUser)
    );

    await click(".users-list .sortable:nth-child(4)");

    assert.equal(find(".admin-title h2").text(), suspectTitle);
    assert.ok(
      find(".users-list .user:nth-child(1) .username")
        .text()
        .includes(suspectUser)
    );

    await click('a[href="/admin/users/list/active"]');

    assert.equal(find(".admin-title h2").text(), activeTitle);
    assert.ok(
      find(".users-list .user:nth-child(1) .username")
        .text()
        .includes(activeUser)
    );
  });
});
