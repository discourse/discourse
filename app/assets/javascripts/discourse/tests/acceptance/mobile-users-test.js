import { exists } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("User Directory - Mobile", function (needs) {
  needs.mobileView();
  test("Visit Page", async (assert) => {
    await visit("/u");
    assert.ok(exists(".directory .user"), "has a list of users");
  });
});
