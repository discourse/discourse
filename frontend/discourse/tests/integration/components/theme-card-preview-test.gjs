import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import ThemeCardPreview from "discourse/components/theme-card-preview";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const THEME = {
  name: "Example",
  screenshot_light_url: "/light.jpg",
  screenshot_dark_url: "/dark.jpg",
};

module("Integration | Component | ThemeCardPreview", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.session = this.owner.lookup("service:session");
    this.session.darkModeAvailable = true;
    this.session.defaultColorSchemeIsDark = false;
    this.interfaceColor = this.owner.lookup("service:interface-color");
    this.prefersDark = (matches) =>
      sinon
        .stub(window, "matchMedia")
        .withArgs("(prefers-color-scheme: dark)")
        .returns({ matches });
  });

  test("follows a color mode forced in the interface over the device preference", async function (assert) {
    this.prefersDark(true);
    this.interfaceColor.colorMode = "light";

    await render(<template><ThemeCardPreview @theme={{THEME}} /></template>);

    assert
      .dom(".theme-card-preview__image")
      .hasAttribute("src", "/light.jpg", "forced light mode shows light");

    this.interfaceColor.colorMode = "dark";
    await settled();

    assert
      .dom(".theme-card-preview__image")
      .hasAttribute("src", "/dark.jpg", "switching the interface follows");
  });

  test("uses the device preference in auto mode", async function (assert) {
    this.prefersDark(true);
    this.interfaceColor.colorMode = "auto";

    await render(<template><ThemeCardPreview @theme={{THEME}} /></template>);

    assert.dom(".theme-card-preview__image").hasAttribute("src", "/dark.jpg");
  });

  test("stays light when the site has no dark mode", async function (assert) {
    this.prefersDark(true);
    this.session.darkModeAvailable = false;

    await render(<template><ThemeCardPreview @theme={{THEME}} /></template>);

    assert.dom(".theme-card-preview__image").hasAttribute("src", "/light.jpg");
  });

  test("keeps the toggled screenshot when the interface changes", async function (assert) {
    this.prefersDark(false);
    this.interfaceColor.colorMode = "light";

    await render(<template><ThemeCardPreview @theme={{THEME}} /></template>);
    await click(".theme-card-preview__screenshot-toggle");

    assert.dom(".theme-card-preview__image").hasAttribute("src", "/dark.jpg");

    this.interfaceColor.colorMode = "light";
    await settled();

    assert
      .dom(".theme-card-preview__image")
      .hasAttribute("src", "/dark.jpg", "an explicit choice is kept");
  });
});
