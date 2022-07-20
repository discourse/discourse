import { test } from "qunit";
import { click, visit } from "@ember/test-helpers";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("Sidebar - Anon User", function () {
  // Don't show sidebar for anon user until we know what we want to display
  test("sidebar is not displayed", async function (assert) {
    await visit("/");

    assert.ok(
      !document.body.classList.contains("has-sidebar-page"),
      "does not add sidebar utility class to body"
    );

    assert.ok(!exists(".sidebar-container"));
  });
});

acceptance("Sidebar - User with sidebar disabled", function (needs) {
  needs.user({ experimental_sidebar_enabled: false });

  test("sidebar is not displayed", async function (assert) {
    await visit("/");

    assert.ok(
      !document.body.classList.contains("has-sidebar-page"),
      "does not add sidebar utility class to body"
    );

    assert.ok(!exists(".sidebar-container"));
  });
});

acceptance("Sidebar - User with sidebar enabled", function (needs) {
  needs.user({ experimental_sidebar_enabled: true });

  test("hiding and displaying sidebar", async function (assert) {
    await visit("/");

    assert.ok(
      document.body.classList.contains("has-sidebar-page"),
      "adds sidebar utility class to body"
    );

    assert.ok(exists(".sidebar-container"), "displays the sidebar by default");

    await click(".header-sidebar-toggle .btn");

    assert.ok(
      !document.body.classList.contains("has-sidebar-page"),
      "removes sidebar utility class to body"
    );

    assert.ok(!exists(".sidebar-container"), "hides the sidebar");

    await click(".header-sidebar-toggle .btn");

    assert.ok(exists(".sidebar-container"), "displays the sidebar");
  });
});
