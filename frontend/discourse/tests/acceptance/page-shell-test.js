import { click, findAll, triggerKeyEvent, visit } from "@ember/test-helpers";
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

  test("the header button opens and closes Context", async function (assert) {
    await visit("/");

    const toggle = "#toggle-context-panel";
    assert
      .dom(toggle)
      .hasAttribute("aria-expanded", "true", "Context starts open");
    assert
      .dom(".page-shell__header-context select")
      .hasValue("overview", "The Context selector is visible above the panel");

    await click(toggle);

    assert
      .dom(toggle)
      .hasAttribute("aria-expanded", "false", "The button reports closed");
    assert.dom("#page-shell-context").doesNotExist("The panel closes");
    assert
      .dom(".page-shell__header-context select")
      .doesNotExist("The Context selector closes with the panel");

    await click(toggle);

    assert
      .dom(toggle)
      .hasAttribute("aria-expanded", "true", "The button reports open");
    assert.dom("#page-shell-context").exists("The panel reopens");
  });

  test("the Navigation toggle collapses to actionable sidebar icons", async function (assert) {
    await visit("/");

    const toggle = ".btn-sidebar-toggle";
    const links = ".page-shell__navigation .sidebar-section-link";
    const expandedCount = findAll(links).length;
    assert.true(expandedCount > 0, "Navigation starts with links");

    await click(toggle);

    assert
      .dom(".page-shell")
      .hasAttribute(
        "data-navigation",
        "rail",
        "Navigation collapses to a rail"
      );
    assert
      .dom(toggle)
      .hasAttribute("aria-expanded", "false", "The toggle reports collapsed");
    assert.true(
      findAll(links).length >= expandedCount,
      "The rail keeps the links"
    );
    assert
      .dom(`${links} .sidebar-section-link-prefix`)
      .exists("Links show icons");

    await click(toggle);

    assert
      .dom(".page-shell")
      .hasAttribute(
        "data-navigation",
        "open",
        "The toggle restores Navigation"
      );
  });

  test("Preferences has no header Context button", async function (assert) {
    await visit("/u/eviltrout/preferences/tracking");

    assert
      .dom("#toggle-context-panel")
      .doesNotExist("Preferences offers no Context panel to open");
  });
});
