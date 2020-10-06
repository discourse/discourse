import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("User Directory - Mobile", { mobileView: true });

QUnit.test("Visit Page", async (assert) => {
  await visit("/u");
  assert.ok(exists(".directory .user"), "has a list of users");
});
