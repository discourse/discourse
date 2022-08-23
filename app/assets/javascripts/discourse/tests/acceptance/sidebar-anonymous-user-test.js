import { test } from "qunit";

import { visit } from "@ember/test-helpers";

import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("Sidebar - Anonymous User", function (needs) {
  needs.settings({
    enable_experimental_sidebar_hamburger: true,
    enable_sidebar: true,
  });

  test("sidebar is displayed", async function (assert) {
    await visit("/");

    assert.ok(
      document.body.classList.contains("has-sidebar-page"),
      "adds sidebar utility class to body"
    );

    assert.ok(
      exists(".sidebar-container"),
      "sidebar exists for anonymous user"
    );
  });
});

acceptance("Sidebar - Anonymous User - Login Required", function (needs) {
  needs.settings({
    enable_experimental_sidebar_hamburger: true,
    enable_sidebar: true,
    login_required: true,
  });

  test("sidebar is hidden", async function (assert) {
    await visit("/");

    assert.ok(
      !exists(".sidebar-container"),
      "sidebar is hidden for anonymous user"
    );
  });
});
