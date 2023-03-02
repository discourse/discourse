import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

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
