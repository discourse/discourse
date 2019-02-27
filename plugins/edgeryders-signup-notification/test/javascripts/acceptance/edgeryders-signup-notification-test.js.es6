import { acceptance } from "helpers/qunit-helpers";

acceptance("EdgerydersSignupNotification", { loggedIn: true });

test("EdgerydersSignupNotification works", async assert => {
  await visit("/admin/plugins/edgeryders-signup-notification");

  assert.ok(false, "it shows the EdgerydersSignupNotification button");
});
