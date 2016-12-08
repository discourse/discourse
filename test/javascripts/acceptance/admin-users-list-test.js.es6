import { acceptance } from "helpers/qunit-helpers";

acceptance("Admin - Users List", { loggedIn: true });

test("lists users", () => {
  visit("/admin/users/list/active");
  andThen(() => {
    ok(exists('.users-list .user'));
    ok(!exists('.user:eq(0) .email small'), 'escapes email');
  });
});
