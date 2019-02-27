import { acceptance } from "helpers/qunit-helpers";

acceptance("EdgerydersCommunitiesNavigation", { loggedIn: true });

test("EdgerydersCommunitiesNavigation works", async assert => {
  await visit("/admin/plugins/edgeryders-communities-navigation");

  assert.ok(false, "it shows the EdgerydersCommunitiesNavigation button");
});
