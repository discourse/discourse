import { findAll, focus, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import InterfaceColorSelector from "discourse/components/interface-color-selector";
import cookie, { removeCookie } from "discourse/lib/cookie";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { i18n } from "discourse-i18n";

const SELECTOR = ".interface-color-selector";
const COOKIE_NAME = "forced_color_mode";

function modeName(mode) {
  return `${i18n("sidebar.footer.interface_color_selector.title")}, ${i18n(
    `sidebar.footer.interface_color_selector.${mode}`
  )}`;
}

module("Integration | Component | InterfaceColorSelector", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    removeCookie(COOKIE_NAME, { path: "/" });
    this.session = this.owner.lookup("service:session");
    this.session.set("darkModeAvailable", true);
    this.session.set("defaultColorSchemeIsDark", false);
    this.interfaceColor = this.owner.lookup("service:interface-color");
    this.interfaceColor.colorMode = undefined;
  });

  hooks.afterEach(function () {
    removeCookie(COOKIE_NAME, { path: "/" });
    this.session.set("darkModeAvailable", null);
    this.session.set("defaultColorSchemeIsDark", null);
  });

  test("keeps today's menu without new select controls", async function (assert) {
    await render(<template><InterfaceColorSelector /></template>);

    assert.dom(`.fk-d-menu__trigger${SELECTOR}`).exists();
    assert.dom(".d-select").doesNotExist();
  });

  module("with new select controls", function (flagHooks) {
    flagHooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
    });

    test("shows only the current mode's icon, and is named by the mode", async function (assert) {
      await render(<template><InterfaceColorSelector /></template>);

      assert.dSelect(SELECTOR).hasValue("auto");
      assert
        .dom(SELECTOR)
        .hasAttribute("role", "combobox")
        .hasAria("label", modeName("auto"))
        .hasAttribute(
          "title",
          i18n("sidebar.footer.interface_color_selector.title")
        );
      assert.dom(`${SELECTOR} .d-icon-circle-half-stroke`).exists();
      assert.dom(`${SELECTOR} .d-select__value`).doesNotExist();
      assert.dom(`${SELECTOR} .d-select__caret`).doesNotExist();
    });

    test("lists the three modes with their icons and checks the current one", async function (assert) {
      await render(<template><InterfaceColorSelector /></template>);
      await dSelect(SELECTOR).open();

      assert.dSelect(SELECTOR).hasOptions(["light", "dark", "auto"]);
      assert.deepEqual(
        findAll("[role='option']").map((row) => row.dataset.name),
        ["light", "dark", "auto"].map((mode) =>
          i18n(`sidebar.footer.interface_color_selector.${mode}`)
        )
      );
      assert.dom("[role='option'][data-value='light'] .d-icon-sun").exists();
      assert.dom("[role='option'][data-value='dark'] .d-icon-moon").exists();
      assert
        .dom("[role='option'][data-value='auto'] .d-icon-circle-half-stroke")
        .exists();
      assert.dSelect(SELECTOR).hasSelectedOption("auto");
      assert
        .dom(
          "[role='option'][data-value='auto'] .d-select__option-selected-icon"
        )
        .exists();
    });

    test("switches to the picked mode and remembers it", async function (assert) {
      await render(<template><InterfaceColorSelector /></template>);
      await dSelect(SELECTOR).select("dark");

      assert.true(this.interfaceColor.darkModeForced);
      assert.strictEqual(cookie(COOKIE_NAME), "dark");
      assert.dSelect(SELECTOR).hasValue("dark");
      assert.dom(SELECTOR).hasAria("label", modeName("dark"));
      assert.dom(`${SELECTOR} .d-icon-moon`).exists();

      await dSelect(SELECTOR).select("auto");

      assert.true(this.interfaceColor.colorModeIsAuto);
      assert.strictEqual(cookie(COOKIE_NAME), "auto");
      assert.dSelect(SELECTOR).hasValue("auto");
    });

    test("starts at a mode picked before", async function (assert) {
      this.interfaceColor.forceLightMode();
      await render(<template><InterfaceColorSelector /></template>);

      assert.dSelect(SELECTOR).hasValue("light");
      assert.dom(SELECTOR).hasAria("label", modeName("light"));
      assert.dom(`${SELECTOR} .d-icon-sun`).exists();
    });

    test("keeps the mode when Backspace is pressed on it, and doesn't say it was cleared", async function (assert) {
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      await render(<template><InterfaceColorSelector /></template>);
      await dSelect(SELECTOR).select("dark");
      await focus(SELECTOR);
      await triggerKeyEvent(SELECTOR, "keydown", "Backspace");

      assert.dSelect(SELECTOR).hasValue("dark");
      assert.true(this.interfaceColor.darkModeForced);
      assert.false(
        announce.calledWith(i18n("d_select.selection_cleared")),
        "nothing was cleared"
      );
    });
  });
});
