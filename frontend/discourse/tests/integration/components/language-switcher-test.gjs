import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import LanguageSwitcher from "discourse/components/language-switcher";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import I18n from "discourse-i18n";

module("Integration | Component | <LanguageSwitcher />", function (hooks) {
  setupRenderingTest(hooks);

  async function open() {
    await triggerEvent(".fk-d-menu__trigger", "click");
  }

  hooks.beforeEach(function () {
    this.siteSettings.available_content_localization_locales = [
      { value: "en" },
      { value: "fr" },
      { value: "de" },
    ];

    this.siteSettings.available_locales = [
      { value: "en", name: "English" },
      { value: "fr", name: "Français (French)" },
      { value: "de", name: "Deutsch (German)" },
    ];
  });

  test("renders the current language code", async function (assert) {
    await render(<template><LanguageSwitcher /></template>);

    assert
      .dom(".language-switcher__locale")
      .hasText(I18n.locale.split("_")[0].toUpperCase());
  });

  test("opens menu with available locales", async function (assert) {
    await render(<template><LanguageSwitcher /></template>);
    await open();

    assert.dom("[data-menu-option-id='en']").exists();
    assert.dom("[data-menu-option-id='fr']").exists();
    assert.dom("[data-menu-option-id='de']").exists();
  });

  test("displays locale names from language lookup service", async function (assert) {
    await render(<template><LanguageSwitcher /></template>);
    await open();

    assert.dom("[data-menu-option-id='en'] .btn").hasText("English");
    assert.dom("[data-menu-option-id='fr'] .btn").hasText("Français (French)");
  });

  test("marks current locale as selected", async function (assert) {
    await render(<template><LanguageSwitcher /></template>);
    await open();

    assert.dom(`[data-menu-option-id='${I18n.locale}']`).hasClass("--selected");
  });

  test("normalizes en_GB when en is not available", async function (assert) {
    this.siteSettings.available_content_localization_locales = [
      { value: "en_GB" },
      { value: "fr" },
    ];

    this.siteSettings.available_locales = [
      { value: "en_GB", name: "English (UK)" },
      { value: "fr", name: "Français (French)" },
    ];

    await render(<template><LanguageSwitcher /></template>);
    await open();

    assert.dom("[data-menu-option-id='en_GB'] .btn").hasText("English");
  });

  test("does not normalize en_GB when en is also available", async function (assert) {
    this.siteSettings.available_content_localization_locales = [
      { value: "en" },
      { value: "en_GB" },
    ];

    this.siteSettings.available_locales = [
      { value: "en", name: "English" },
      { value: "en_GB", name: "English (UK)" },
    ];

    await render(<template><LanguageSwitcher /></template>);
    await open();

    assert.dom("[data-menu-option-id='en_GB'] .btn").hasText("English (UK)");
  });

  test("normalizes pt_BR when pt is not available", async function (assert) {
    this.siteSettings.available_content_localization_locales = [
      { value: "pt_BR" },
      { value: "en" },
    ];

    this.siteSettings.available_locales = [
      { value: "pt_BR", name: "Portuguese (Português (BR))" },
      { value: "en", name: "English" },
    ];

    await render(<template><LanguageSwitcher /></template>);
    await open();

    assert
      .dom("[data-menu-option-id='pt_BR'] .btn")
      .hasText("Portuguese (Português)");
  });

  test("does not normalize pt_BR when pt is also available", async function (assert) {
    this.siteSettings.available_content_localization_locales = [
      { value: "pt" },
      { value: "pt_BR" },
    ];

    this.siteSettings.available_locales = [
      { value: "pt", name: "Português" },
      { value: "pt_BR", name: "Português (Português (BR))" },
    ];

    await render(<template><LanguageSwitcher /></template>);
    await open();

    assert
      .dom("[data-menu-option-id='pt_BR'] .btn")
      .hasText("Português (Português (BR))");
  });
});
