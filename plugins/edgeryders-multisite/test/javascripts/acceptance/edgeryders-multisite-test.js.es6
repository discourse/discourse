import { acceptance } from "helpers/qunit-helpers";

acceptance("EdgerydersMultisite", { loggedIn: true });

test("EdgerydersMultisite works", async assert => {
  await visit("/admin/plugins/edgeryders-multisite");

  assert.ok(false, "it shows the EdgerydersMultisite button");
});
