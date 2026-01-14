import { currentRouteName, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Wizard", function (needs) {
  needs.user();

  test("Wizard starts", async function (assert) {
    await visit("/wizard");
    assert.dom(".wizard-container").exists();
    assert
      .dom(".d-header-wrap")
      .doesNotExist("header is not rendered on wizard pages");
    assert.strictEqual(currentRouteName(), "wizard.step");
  });
});
