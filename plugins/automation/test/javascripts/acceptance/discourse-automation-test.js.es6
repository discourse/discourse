import { acceptance } from "helpers/qunit-helpers";

acceptance("discourse-automation", { loggedIn: true });

test("discourse-automation works", async assert => {
  await visit("/admin/plugins/discourse-automation");

  assert.ok(false, "it shows the discourse-automation button");
});
