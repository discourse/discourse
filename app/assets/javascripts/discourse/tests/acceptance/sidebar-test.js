import { click, visit } from "@ember/test-helpers";
import {
  acceptance,
  conditionalTest,
  exists,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { isLegacyEmber } from "discourse-common/config/environment";

acceptance("Sidebar - Anon User", function () {
  // Don't show sidebar for anon user until we know what we want to display
  test("sidebar is not displayed", async function (assert) {
    await visit("/");

    assert.ok(!exists("#main-outlet-wrapper.has-sidebar"));
    assert.ok(!exists(".sidebar-wrapper"));
  });
});

acceptance("Sidebar - User with sidebar disabled", function (needs) {
  needs.user({ experimental_sidebar_enabled: false });

  conditionalTest(
    "sidebar is not displayed",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/");

      assert.ok(!exists("#main-outlet-wrapper.has-sidebar"));
      assert.ok(!exists(".sidebar-wrapper"));
    }
  );
});

acceptance("Sidebar - User with sidebar enabled", function (needs) {
  needs.user({ experimental_sidebar_enabled: true });

  conditionalTest(
    "hiding and displaying sidebar",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/");

      assert.ok(
        exists("#main-outlet-wrapper.has-sidebar"),
        "adds sidebar utility class on main outlet wrapper"
      );

      assert.ok(exists(".sidebar-wrapper"), "displays the sidebar by default");

      await click(".header-sidebar-toggle .btn");

      assert.ok(
        !exists("#main-outlet-wrapper.has-sidebar"),
        "removes sidebar utility class from main outlet wrapper"
      );

      assert.ok(!exists(".sidebar-wrapper"), "hides the sidebar");

      await click(".header-sidebar-toggle .btn");

      assert.ok(exists(".sidebar-wrapper"), "displays the sidebar");
    }
  );
});
