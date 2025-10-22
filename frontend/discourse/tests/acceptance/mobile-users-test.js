import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("User Directory - Mobile", function (needs) {
  needs.mobileView();

  test("Visit Page", async function (assert) {
    await visit("/u");
    assert
      .dom(".directory .directory-table__row")
      .exists("has a list of users");
  });
});
