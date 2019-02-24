import { acceptance } from "helpers/qunit-helpers";

acceptance("Admin - Users List", { loggedIn: true });

QUnit.test("lists users", async assert => {
  await visit("/admin/users/list/active");

  assert.ok(exists(".users-list .user"));
  assert.ok(!exists(".user:eq(0) .email small"), "escapes email");
});

QUnit.test("switching tabs", async assert => {
  const activeUser = "<small>eviltrout@example.com</small>";
  const suspectUser = "<small>sam@example.com</small>";
  const activeTitle = I18n.t("admin.users.titles.active");
  const suspectTitle = I18n.t("admin.users.titles.suspect");

  await visit("/admin/users/list/active");

  assert.equal(find(".admin-title h2").text(), activeTitle);
  assert.equal(
    find(".users-list .user:nth-child(1) .email").text(),
    activeUser
  );

  await click('a[href="/admin/users/list/suspect"]');

  assert.equal(find(".admin-title h2").text(), suspectTitle);
  assert.equal(
    find(".users-list .user:nth-child(1) .email").text(),
    suspectUser
  );

  await click(".users-list .sortable:nth-child(4)");

  assert.equal(find(".admin-title h2").text(), suspectTitle);
  assert.equal(
    find(".users-list .user:nth-child(1) .email").text(),
    suspectUser
  );

  await click('a[href="/admin/users/list/active"]');

  assert.equal(find(".admin-title h2").text(), activeTitle);
  assert.equal(
    find(".users-list .user:nth-child(1) .email").text(),
    activeUser
  );
});
