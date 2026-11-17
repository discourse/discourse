import { click, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Page shell | narrow screen menus", function (needs) {
  needs.user();
  needs.mobileView();
  needs.settings({
    enable_page_shell_prototype: true,
    enable_main_outlet_grid_layout_change: true,
    navigation_menu: "sidebar",
  });

  test("Escape closes navigation and restores the opener", async function (assert) {
    await visit("/");
    await click("#toggle-hamburger-menu");
    assert.dom(".sidebar-hamburger-dropdown").exists();

    await triggerKeyEvent(".sidebar-hamburger-dropdown a", "keydown", "Escape");

    assert.dom(".sidebar-hamburger-dropdown").doesNotExist();
    assert.dom("#toggle-hamburger-menu").isFocused();
  });

  test("Escape closes the user menu and restores the opener", async function (assert) {
    await visit("/");
    await click("#toggle-current-user");
    assert.dom(".user-menu").exists();

    await triggerKeyEvent(".user-menu", "keydown", "Escape");

    assert.dom(".user-menu").doesNotExist();
    assert.dom("#toggle-current-user").isFocused();
  });

  test("a nested control can claim Escape", async function (assert) {
    await visit("/");
    await click("#toggle-hamburger-menu");
    const link = document.querySelector(".sidebar-hamburger-dropdown a");
    link.addEventListener("keydown", (event) => event.preventDefault(), {
      once: true,
    });

    await triggerKeyEvent(link, "keydown", "Escape");

    assert.dom(".sidebar-hamburger-dropdown").exists();
  });
});

acceptance("Page shell | regions", function (needs) {
  needs.user();
  needs.settings({
    enable_page_shell_prototype: true,
    enable_main_outlet_grid_layout_change: true,
    navigation_menu: "sidebar",
  });

  test("the shell owns its page regions and composer directly", async function (assert) {
    await visit("/");

    const shell = "#main-outlet-wrapper.page-shell";
    assert.dom("#main-outlet-wrapper").exists({ count: 1 });
    assert.dom(`${shell} > .page-shell__header`).exists();
    assert.dom(`${shell} > .sidebar-wrapper.page-shell__navigation`).exists();
    assert.dom(`${shell} > main#main-outlet.page-shell__main`).exists();
    assert.dom(`${shell} > footer.page-shell__footer`).exists();
    assert.dom(`${shell} > aside.page-shell__context`).exists();
    assert.dom(`${shell} > #reply-control`).exists();
    assert.dom(`${shell} > .powered-by-discourse`).doesNotExist();
    assert.dom("main, [role=main]").exists({ count: 1 });
  });
});
