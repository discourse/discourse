import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("User Directory - Mobile", function (needs) {
  needs.mobileView();

  test("Visit Page", async function (assert) {
    await visit("/u");
    assert.ok(
      exists(".directory .directory-table__row"),
      "has a list of users"
    );
  });
});
