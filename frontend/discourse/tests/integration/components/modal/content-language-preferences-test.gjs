import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ContentLanguagePreferences from "discourse/components/modal/content-language-preferences";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const ALL_LOCALES = [
  { name: "English", value: "en" },
  { name: "Español", value: "es" },
  { name: "Français", value: "fr" },
  { name: "日本語", value: "ja" },
];

const CONFIGURED_LOCALES = [
  { name: "English", value: "en" },
  { name: "Español", value: "es" },
];

module(
  "Integration | Component | Modal | content-language-preferences",
  function (hooks) {
    // The interface language field is only editable by anonymous visitors when something
    // honours the `locale` cookie, so these cases have to run without a current user.
    setupRenderingTest(hooks, { anonymous: true });

    hooks.beforeEach(function () {
      this.siteSettings.available_locales = ALL_LOCALES;
      this.siteSettings.available_content_localization_locales =
        CONFIGURED_LOCALES;
      this.siteSettings.allow_user_locale = true;
    });

    const noop = () => {};

    test("anonymous visitors only get the locales the switcher honours", async function (assert) {
      this.siteSettings.set_locale_from_cookie = false;
      this.siteSettings.content_localization_enabled = true;
      this.siteSettings.content_localization_supported_locales = "es";
      this.siteSettings.content_localization_language_switcher = "all";

      await render(
        <template>
          <ContentLanguagePreferences @closeModal={{noop}} @inline={{true}} />
        </template>
      );

      assert
        .dom(".content-language-preferences-modal select")
        .exists({ count: 1 });
      assert
        .dom(".content-language-preferences-modal select option")
        .exists(
          { count: 2 },
          "only the configured locales are offered, since the server discards the rest"
        );
      assert.dom(".content-language-preferences-modal select").isNotDisabled();
    });

    test("set_locale_from_cookie keeps the full locale list", async function (assert) {
      this.siteSettings.set_locale_from_cookie = true;
      this.siteSettings.content_localization_enabled = true;
      this.siteSettings.content_localization_supported_locales = "es";
      this.siteSettings.content_localization_language_switcher = "none";

      await render(
        <template>
          <ContentLanguagePreferences @closeModal={{noop}} @inline={{true}} />
        </template>
      );

      assert
        .dom(".content-language-preferences-modal select option")
        .exists(
          { count: 4 },
          "the server honours any available locale, so offer them all"
        );
    });

    test("the interface language is read-only when nothing honours the cookie", async function (assert) {
      this.siteSettings.set_locale_from_cookie = false;
      this.siteSettings.content_localization_enabled = true;
      this.siteSettings.content_localization_supported_locales = "es";
      this.siteSettings.content_localization_language_switcher = "none";

      await render(
        <template>
          <ContentLanguagePreferences @closeModal={{noop}} @inline={{true}} />
        </template>
      );

      assert.dom(".content-language-preferences-modal select").isDisabled();
      assert
        .dom(".content-language-preferences-modal select option")
        .exists(
          { count: 4 },
          "the read-only field still shows the full list so the current locale resolves"
        );
    });
  }
);
