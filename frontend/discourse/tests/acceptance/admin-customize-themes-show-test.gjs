import {
  click,
  currentURL,
  fillIn,
  visit,
  waitUntil,
} from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import pretender from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Admin - Customize - Themes - Show", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/admin/themes", () => {
      return helper.response({
        themes: [
          {
            id: -1,
            name: "Foundation",
            description:
              "The classic Discourse theme that is well-suited to customization for your community’s specific needs.",
            created_at: "2025-06-11T23:50:31.187Z",
            updated_at: "2025-06-12T03:09:26.162Z",
            default: true,
            component: false,
            color_scheme_id: 6,
            user_selectable: false,
            auto_update: false,
            remote_theme_id: null,
            settings: [],
            supported: true,
            enabled: true,
            theme_fields: [
              {
                name: "screenshot_light",
                target: "common",
                value: "",
                type_id: 7,
                upload_id: 83,
                url: "/uploads/default/original/1X/f8a61b9a0bfac672daec9e401787812f8c5e28df.png",
                filename: "light.png",
              },
              {
                name: "screenshot_dark",
                target: "common",
                value: "",
                type_id: 7,
                upload_id: 84,
                url: "/uploads/default/original/1X/783d7817fd5e44b15d3532ffb13d2f70174a039f.png",
                filename: "dark.png",
              },
              {
                name: "en",
                target: "translations",
                value:
                  'en:\n  theme_metadata:\n    description: "The classic Discourse theme that is well-suited to customization for your community’s specific needs."\n',
                type_id: 5,
              },
            ],
            screenshot_light_url:
              "/uploads/default/original/1X/f8a61b9a0bfac672daec9e401787812f8c5e28df.png",
            system: true,
            color_scheme: null,
            user: {
              id: -1,
              username: "system",
              name: "system",
              avatar_template: "/images/discourse-logo-sketch-small.png",
              title: null,
            },
            child_themes: [],
            parent_themes: [],
            remote_theme: null,
            translations: [
              {
                key: "theme_metadata.description",
                value: "The classic Discourse theme...",
                default: "The classic Discourse theme...",
              },
            ],
          },
          {
            id: 42,
            name: "Git theme",
            created_at: "2025-06-11T23:50:31.187Z",
            updated_at: "2025-06-12T03:09:26.162Z",
            default: false,
            component: false,
            user_selectable: false,
            auto_update: false,
            remote_theme_id: 42,
            settings: [],
            supported: true,
            enabled: true,
            theme_fields: [],
            system: false,
            color_scheme: null,
            user: {
              id: -1,
              username: "system",
              name: "system",
              avatar_template: "/images/discourse-logo-sketch-small.png",
              title: null,
            },
            child_themes: [],
            parent_themes: [],
            remote_theme: {
              id: 42,
              remote_url: "https://github.com/example/theme.git",
              remote_version: "def456",
              local_version: "abc123",
              commits_behind: 2,
              branch: "main",
              is_git: true,
              local_compat_ref: "d-compat/2026.5",
              remote_compat_ref: "d-compat/2026.5",
            },
            translations: [],
          },
        ],
      });
    });

    server.get("/admin/config/customize/themes", () => {
      return helper.response({ themes: [] });
    });
  });

  test("admin-customize-theme-included-components-setting plugin outlet", async function (assert) {
    withPluginApi((api) => {
      api.renderInOutlet(
        "admin-customize-theme-included-components-setting",
        <template>
          <p class="custom-element-in-place-of-included-components">
            This is a custom element that replaces the included components
            setting.
          </p>
        </template>
      );
    });

    await visit("/admin/customize/themes/-1");
    assert
      .dom(".included-components-setting .select-kit")
      .doesNotExist(
        "the included components setting is replaced by a custom element"
      );
    assert
      .dom(
        ".included-components-setting .custom-element-in-place-of-included-components"
      )
      .hasText(
        "This is a custom element that replaces the included components setting."
      );
  });

  test("admin-customize-theme-translation-selector plugin outlet exposes the theme", async function (assert) {
    withPluginApi((api) => {
      api.renderInOutlet(
        "admin-customize-theme-translation-selector",
        <template>
          <span class="theme-translation-outlet-test">
            theme:{{@outletArgs.theme.id}}
          </span>
        </template>
      );
    });

    await visit("/admin/customize/themes/-1");
    assert
      .dom(".translation-selector-container .theme-translation-outlet-test")
      .hasText(
        "theme:-1",
        "the theme id is exposed via outletArgs on the translation selector outlet"
      );
  });

  test("shows the compatibility-pinned ref for the pending update", async function (assert) {
    await visit("/admin/customize/themes/42");

    assert
      .dom(".status-message")
      .includesText(
        "Theme is 2 commits behind d-compat/2026.5",
        "the compat ref is interpolated into the commits-behind message"
      );
    assert
      .dom(".status-message code")
      .hasText("d-compat/2026.5", "the ref is rendered inside a code tag");
  });
});

acceptance(
  "Admin - Customize - Themes - Show - Color palettes",
  function (needs) {
    needs.user();

    let savedThemes = [];

    needs.pretender((server, helper) => {
      const theme = {
        id: 7,
        name: "Palette theme",
        default: false,
        component: false,
        color_scheme_id: 1,
        dark_color_scheme_id: 2,
        user_selectable: false,
        auto_update: false,
        remote_theme_id: null,
        settings: [],
        supported: true,
        enabled: true,
        theme_fields: [],
        system: false,
        color_scheme: null,
        child_themes: [],
        parent_themes: [],
        remote_theme: null,
        translations: [],
      };

      server.get("/admin/themes", () => {
        return helper.response({
          themes: [theme],
          extras: {
            color_schemes: [
              { id: 1, name: "Morning" },
              { id: 2, name: "Night", is_dark: true },
              { id: 3, name: "Noon" },
              { id: 4, name: "Midnight", is_dark: true },
            ],
          },
        });
      });

      server.put("/admin/themes/7", (request) => {
        const saved = JSON.parse(request.requestBody).theme;
        savedThemes.push(saved);
        return helper.response({ theme: { ...theme, ...saved } });
      });

      server.get("/admin/config/customize/themes", () => {
        return helper.response({ themes: [] });
      });
    });

    needs.hooks.beforeEach(() => (savedThemes = []));

    test("saves the selected light color palette", async function (assert) {
      await visit("/admin/customize/themes/7");

      assert
        .dom(".submit-light-edit")
        .doesNotExist("does not offer to save an unchanged palette");

      const lightPalette = selectKit(
        ".theme-settings__light-color-scheme .color-palette-picker"
      );
      await lightPalette.expand();
      await lightPalette.selectRowByValue(3);

      assert.strictEqual(
        lightPalette.header().value(),
        "3",
        "shows the chosen palette"
      );

      await click(".submit-light-edit");

      assert.deepEqual(
        savedThemes,
        [{ color_scheme_id: 3 }],
        "saves the chosen palette as the light palette"
      );
    });

    test("saves the selected dark color palette", async function (assert) {
      await visit("/admin/customize/themes/7");

      assert
        .dom(".submit-dark-edit")
        .doesNotExist("does not offer to save an unchanged palette");

      const darkPalette = selectKit(
        ".theme-settings__dark-color-scheme .color-palette-picker"
      );
      await darkPalette.expand();
      await darkPalette.selectRowByValue(4);

      assert.strictEqual(
        darkPalette.header().value(),
        "4",
        "shows the chosen palette"
      );

      await click(".submit-dark-edit");

      assert.deepEqual(
        savedThemes,
        [{ dark_color_scheme_id: 4 }],
        "saves the chosen palette as the dark palette"
      );
    });
  }
);

acceptance(
  "Admin - Customize - Themes - Translation refresh",
  function (needs) {
    needs.user();
    needs.settings({
      available_locales: [
        { name: "English", value: "en" },
        { name: "French", value: "fr" },
      ],
    });

    let greeting,
      holdTranslations,
      translationRequest,
      collectionLocale,
      themeCollectionRequests;
    needs.hooks.beforeEach(() => {
      greeting = "Original greeting";
      holdTranslations = false;
      translationRequest = null;
      collectionLocale = "en";
      themeCollectionRequests = 0;
    });
    needs.pretender((server, helper) => {
      server.get("/admin/themes", () => {
        themeCollectionRequests++;
        return helper.response({
          themes: [
            {
              id: 7,
              translations_locale: collectionLocale,
              name: "Translated objects",
              component: false,
              theme_fields: [],
              child_themes: [],
              parent_themes: [],
              settings: [
                {
                  setting: "cards",
                  type: "objects",
                  default: [],
                  value: [],
                  objects_schema: {
                    name: "card",
                    properties: {
                      title: { type: "string", translatable: true },
                    },
                  },
                },
              ],
              translations: [
                { key: "greeting", value: greeting, default: greeting },
              ],
            },
            {
              id: 8,
              translations_locale: collectionLocale,
              name: "Other theme",
              component: false,
              theme_fields: [],
              child_themes: [],
              parent_themes: [],
              settings: [],
              translations: [
                {
                  key: "greeting",
                  value:
                    collectionLocale === "fr"
                      ? "Bonjour"
                      : "Other theme greeting",
                  default:
                    collectionLocale === "fr"
                      ? "Bonjour"
                      : "Other theme greeting",
                },
              ],
            },
          ],
          extras: { locale: collectionLocale },
        });
      });
      server.get(
        "/admin/themes/7/translations/en",
        (request) => {
          translationRequest = request;
          return helper.response({
            translations: [
              { key: "greeting", value: greeting, default: greeting },
            ],
          });
        },
        () => holdTranslations
      );
      server.get(
        "/admin/themes/8/translations/fr",
        (request) => {
          translationRequest = request;
          return helper.response({
            translations: [
              { key: "greeting", value: "Bonjour", default: "Bonjour" },
            ],
          });
        },
        () => holdTranslations
      );
      server.get("/admin/config/customize/themes", () =>
        helper.response({
          themes: [
            { id: 7, name: "Translated objects", component: false },
            { id: 8, name: "Other theme", component: false },
          ],
        })
      );
      server.get("/admin/themes/8/translations/en", () =>
        helper.response({
          translations: [
            {
              key: "greeting",
              value: "Other theme greeting",
              default: "Other theme greeting",
            },
          ],
        })
      );
      server.get("/admin/themes/7/translations/fr", () =>
        helper.response({
          translations: [
            {
              key: "greeting",
              value: "Bonjour objets",
              default: "Bonjour objets",
            },
          ],
        })
      );
      server.get("/admin/themes/7/objects_setting_metadata/cards.json", () =>
        helper.response({})
      );
    });

    test("keeps an unsaved translation when returning from the object editor", async function (assert) {
      await visit("/admin/customize/themes/7");
      await fillIn(".theme-translation textarea", "Unsaved greeting");
      await click('[data-setting="cards"] .setting-value-edit-button');
      await click(".customize-show-schema__back");

      assert.dom(".theme-translation textarea").hasValue("Unsaved greeting");
      assert.dom(".theme-translation .setting-controls .ok").exists();
    });

    test("a delayed response cannot populate another theme after navigation", async function (assert) {
      holdTranslations = true;
      const firstVisit = visit("/admin/customize/themes/7");
      await waitUntil(() => translationRequest);
      const secondVisit = visit("/admin/customize/themes/8");
      await waitUntil(() => currentURL() === "/admin/customize/themes/8");
      pretender.resolve(translationRequest);
      await Promise.all([firstVisit, secondVisit]);

      assert
        .dom(".theme-translation textarea")
        .hasValue("Other theme greeting");
    });

    test("returning to a theme keeps its selected locale and translation text in sync", async function (assert) {
      await visit("/admin/customize/themes/8");
      const selector = selectKit(".translation-selector");
      await selector.expand();
      holdTranslations = true;
      const localeChange = selector.selectRowByValue("fr");
      await waitUntil(() => translationRequest);
      const pendingRequest = translationRequest;
      holdTranslations = false;
      const otherVisit = visit("/admin/customize/themes/7");
      await waitUntil(() => currentURL() === "/admin/customize/themes/7");
      pretender.resolve(pendingRequest);
      await Promise.all([localeChange, otherVisit]);

      assert.dom(".theme-translation textarea").hasValue("Original greeting");
      await visit("/admin/customize/themes/8");
      assert.strictEqual(
        selectKit(".translation-selector").header().value(),
        "fr"
      );
      assert.dom(".theme-translation textarea").hasValue("Bonjour");
    });

    test("theme-card navigation preserves French text with the selected French locale", async function (assert) {
      await visit("/admin/customize/themes/8");
      const selector = selectKit(".translation-selector");
      await selector.expand();
      await selector.selectRowByValue("fr");
      assert.dom(".theme-translation textarea").hasValue("Bonjour");

      await click(".back-to-themes-and-components a");
      await click('.theme-card__title[href="/admin/customize/themes/7"]');
      await click(".back-to-themes-and-components a");
      await click('.theme-card__title[href="/admin/customize/themes/8"]');

      assert.true(
        themeCollectionRequests > 1,
        "the theme collection was fetched again"
      );
      assert.strictEqual(
        selectKit(".translation-selector").header().value(),
        "fr"
      );
      assert.dom(".theme-translation textarea").hasValue("Bonjour");
    });

    test("theme-card navigation preserves English text when the collection locale is French", async function (assert) {
      collectionLocale = "fr";
      await visit("/admin/customize/themes/8");
      const selector = selectKit(".translation-selector");
      await selector.expand();
      await selector.selectRowByValue("en");
      assert
        .dom(".theme-translation textarea")
        .hasValue("Other theme greeting");

      await click(".back-to-themes-and-components a");
      await click('.theme-card__title[href="/admin/customize/themes/7"]');
      await click(".back-to-themes-and-components a");
      await click('.theme-card__title[href="/admin/customize/themes/8"]');

      assert.true(
        themeCollectionRequests > 1,
        "the theme collection was fetched again"
      );
      assert.strictEqual(
        selectKit(".translation-selector").header().value(),
        "en"
      );
      assert
        .dom(".theme-translation textarea")
        .hasValue("Other theme greeting");
    });

    test("refreshes translations when returning without a draft", async function (assert) {
      await visit("/admin/customize/themes/7");
      await click('[data-setting="cards"] .setting-value-edit-button');
      greeting = "Updated object greeting";
      await click(".customize-show-schema__back");

      assert.dom(".theme-translation textarea").hasValue(greeting);
    });
  }
);
