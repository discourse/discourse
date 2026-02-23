import { click, settled, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import NarrowDesktop, {
  forceNarrowDesktop,
  resetNarrowDesktop,
} from "discourse/lib/narrow-desktop";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

async function simulateNarrowDesktop(owner) {
  forceNarrowDesktop();
  NarrowDesktop.init();
  NarrowDesktop.update(owner, true);
  await settled();
}

async function simulateWideDesktop(owner) {
  resetNarrowDesktop();
  NarrowDesktop.init();
  NarrowDesktop.update(owner, false);
  await settled();
}

acceptance("Sidebar - Narrow Desktop", function (needs) {
  needs.user();

  needs.settings({
    navigation_menu: "sidebar",
  });

  needs.hooks.afterEach(function () {
    resetNarrowDesktop();
  });

  test("wide sidebar is changed to cloak when resize to narrow screen", async function (assert) {
    await visit("/");
    assert.dom("#d-sidebar").exists("wide sidebar is displayed");

    await click(".header-sidebar-toggle .btn");

    assert.dom("#d-sidebar").doesNotExist("wide sidebar is collapsed");

    await click(".header-sidebar-toggle .btn");

    assert.dom("#d-sidebar").exists("wide sidebar is displayed");

    await simulateNarrowDesktop(this.owner);
    await click(".btn-sidebar-toggle");

    assert
      .dom(".sidebar-hamburger-dropdown")
      .exists("cloak sidebar is displayed");

    await triggerEvent(".header-cloak", "pointerdown");

    assert
      .dom(".sidebar-hamburger-dropdown")
      .doesNotExist("cloak sidebar is collapsed");

    await simulateWideDesktop(this.owner);
    assert.dom("#d-sidebar").exists("wide sidebar is displayed");
  });

  test("transition from narrow screen to wide screen", async function (assert) {
    await visit("/");

    await simulateNarrowDesktop(this.owner);
    await click(".btn-sidebar-toggle");

    await simulateWideDesktop(this.owner);

    await click(".header-dropdown-toggle.current-user button");

    assert.dom(".quick-access-panel").exists();
  });
});
