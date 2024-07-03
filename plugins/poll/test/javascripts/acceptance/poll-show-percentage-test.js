import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("Poll show percentage button", function (needs) {
  needs.user();
  needs.settings({ poll_enabled: true });

  test("Displaying the show percentage button", async function (assert) {
    await visit("/t/-/15");
    await click(".toggle-results");

    assert.ok(exists(".option .percentage"), "displays the percentage firstly");

    async function toggleOnce() {
      if (exists(".toggle-percentage")) {
        await click(".toggle-percentage");
      } else {
        await click(".widget-dropdown-header");
        assert.ok(
          exists(".item-togglePercentage"),
          "shows the toggle percentage button in the bar"
        );
        await click(".item-togglePercentage");
      }
    }

    await toggleOnce();

    assert.ok(exists(".option .absolute"), "displays the absolute vote count");

    await toggleOnce();

    assert.ok(exists(".option .percentage"), "displays the percentage again");
  });
});
