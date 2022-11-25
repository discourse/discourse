import { test } from "qunit";

import { click, settled, visit, waitUntil } from "@ember/test-helpers";

import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("Sidebar - Narrow Desktop", function (needs) {
  needs.user();

  needs.settings({
    enable_experimental_sidebar_hamburger: true,
    enable_sidebar: true,
  });

  needs.hooks.beforeEach(function () {
    window.oldWidth = window.innerWidth;
    window.innerWidth = 1280;
  });
  needs.hooks.afterEach(function () {
    $("body").width(window.oldWidth);
    delete window.oldWidth;
  });

  test("wide sidebar is changed to cloak when resize to narrow screen", async function (assert) {
    await visit("/");
    await settled();
    assert.ok(exists("#d-sidebar"), "wide sidebar is displayed");

    await click(".header-sidebar-toggle .btn");

    assert.ok(!exists("#d-sidebar"), "widge sidebar is collapsed");

    $("body").width(1000);

    await waitUntil(
      () => document.querySelector(".btn-sidebar-toggle.narrow-desktop"),
      {
        timeout: 5000,
      }
    );
    await click(".btn-sidebar-toggle");

    assert.ok(
      exists(".sidebar-hamburger-dropdown"),
      "cloak sidebar is displayed"
    );

    await click("#main-outlet");
    assert.ok(
      !exists(".sidebar-hamburger-dropdown"),
      "cloak sidebar is collapsed"
    );
  });
});
