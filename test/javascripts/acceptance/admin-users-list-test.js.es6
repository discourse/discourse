import { acceptance } from "helpers/qunit-helpers";

acceptance("Admin - Users List", { loggedIn: true });

QUnit.test("lists users", assert => {
  visit("/admin/users/list/active");
  andThen(() => {
    assert.ok(exists(".users-list .user"));
    assert.ok(!exists(".user:eq(0) .email small"), "escapes email");
  });
});
