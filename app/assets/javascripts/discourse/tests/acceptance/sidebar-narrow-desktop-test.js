import { test } from "qunit";

import { click, settled, visit } from "@ember/test-helpers";

import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("Sidebar - Narrow Desktop", function (needs) {
  needs.user();

  needs.settings({
    enable_experimental_sidebar_hamburger: true,
    enable_sidebar: true,
  });

  needs.hooks.beforeEach(function () {
    window.innerWidth = 1280;
  });

  test("wide sidebar is changed to cloak when resize to narrow screen", async function (assert) {
    await visit("/");
    await settled();

    assert.ok(exists("#d-sidebar"), "wide sidebar is displayed");

    await click(".header-sidebar-toggle .btn");

    assert.ok(!exists("#d-sidebar"), "widge sidebar is collapsed");

    $("body").width(500);

    await settled();
    await click(".btn-sidebar-toggle");
    await settled();

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
