import { acceptance } from "helpers/qunit-helpers";

acceptance("User Directory - Mobile", { mobileView: true });

QUnit.test("Visit Page", async assert => {
  await visit("/users");
  assert.ok(exists(".directory .user"), "has a list of users");
});
