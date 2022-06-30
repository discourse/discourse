import { test } from "qunit";

import { click, visit } from "@ember/test-helpers";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("Sidebar - Anon User", function () {
  // Don't show sidebar for anon user until we know what we want to display
  test("sidebar is not displayed", async function (assert) {
    await visit("/");

    assert.strictEqual(
      document.querySelectorAll("body.has-sidebar-page").length,
      0,
      "does not add sidebar utility class to body"
    );

    assert.ok(!exists(".sidebar-wrapper"));
  });
});

acceptance("Sidebar - User with sidebar disabled", function (needs) {
  needs.user({ experimental_sidebar_enabled: false });

  test("sidebar is not displayed", async function (assert) {
    await visit("/");

    assert.strictEqual(
      document.querySelectorAll("body.has-sidebar-page").length,
      0,
      "does not add sidebar utility class to body"
    );

    assert.ok(!exists(".sidebar-wrapper"));
  });
});

acceptance("Sidebar - User with sidebar enabled", function (needs) {
  needs.user({ experimental_sidebar_enabled: true });

  test("hiding and displaying sidebar", async function (assert) {
    await visit("/");

    assert.strictEqual(
      document.querySelectorAll("body.has-sidebar-page").length,
      1,
      "adds sidebar utility class to body"
    );

    assert.ok(exists(".sidebar-wrapper"), "displays the sidebar by default");

    await click(".header-sidebar-toggle .btn");

    assert.strictEqual(
      document.querySelectorAll("body.has-sidebar-page").length,
      0,
      "removes sidebar utility class to body"
    );

    assert.ok(!exists(".sidebar-wrapper"), "hides the sidebar");

    await click(".header-sidebar-toggle .btn");

    assert.ok(exists(".sidebar-wrapper"), "displays the sidebar");
  });
});
