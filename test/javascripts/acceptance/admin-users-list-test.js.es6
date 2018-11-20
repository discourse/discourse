import { acceptance } from "helpers/qunit-helpers";

acceptance("Admin - Users List", { loggedIn: true });

QUnit.test("lists users", async assert => {
  await visit("/admin/users/list/active");

  assert.ok(exists(".users-list .user"));
  assert.ok(!exists(".user:eq(0) .email small"), "escapes email");
});
