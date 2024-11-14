import { click, triggerEvent, visit, waitFor } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Sidebar - Narrow Desktop", function (needs) {
  needs.user();

  needs.settings({
    navigation_menu: "sidebar",
  });

  needs.hooks.afterEach(function () {
    document.body.style.width = null;
  });

  test("wide sidebar is changed to cloak when resize to narrow screen", async function (assert) {
    await visit("/");
    assert.dom("#d-sidebar").exists("wide sidebar is displayed");

    await click(".header-sidebar-toggle .btn");

    assert.dom("#d-sidebar").doesNotExist("wide sidebar is collapsed");

    await click(".header-sidebar-toggle .btn");

    assert.dom("#d-sidebar").exists("wide sidebar is displayed");

    document.body.style.width = "767px";

    await waitFor(".btn-sidebar-toggle.narrow-desktop", {
      timeout: 5000,
    });
    await click(".btn-sidebar-toggle");

    assert
      .dom(".sidebar-hamburger-dropdown")
      .exists("cloak sidebar is displayed");

    await triggerEvent(document.querySelector(".header-cloak"), "pointerdown");

    assert
      .dom(".sidebar-hamburger-dropdown")
      .doesNotExist("cloak sidebar is collapsed");

    document.body.style.width = "1200px";
    await waitFor("#d-sidebar", {
      timeout: 5000,
    });
    assert.dom("#d-sidebar").exists("wide sidebar is displayed");
  });

  test("transition from narrow screen to wide screen", async function (assert) {
    await visit("/");

    document.body.style.width = "767px";

    await waitFor(".btn-sidebar-toggle.narrow-desktop", {
      timeout: 5000,
    });
    await click(".btn-sidebar-toggle");

    document.body.style.width = "1200px";
    await waitFor("#d-sidebar", {
      timeout: 5000,
    });

    await click(".header-dropdown-toggle.current-user button");

    assert.dom(".quick-access-panel").exists();
  });
});
