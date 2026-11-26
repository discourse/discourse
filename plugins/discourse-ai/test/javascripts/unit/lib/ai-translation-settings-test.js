import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SiteSetting from "discourse/admin/models/site-setting";
import { i18n } from "discourse-i18n";
import {
  TRANSLATION_SETTING_GROUPS,
  TRANSLATION_SETTING_NAMES,
  translationSettingAvailable,
  translationSettingDefinition,
  translationSettingVisible,
} from "discourse/plugins/discourse-ai/discourse/lib/ai-translation-settings";

// Every setting the translation settings page used to own, so consolidation
// into this page cannot drop one. The AI flag moved to the page header switch.
const PREVIOUSLY_GROUPED_SETTINGS = [
  "ai_translation_locale_detector_agent",
  "ai_translation_locale_detector_decision_model",
  "ai_translation_post_raw_translator_agent",
  "ai_translation_topic_title_translator_agent",
  "ai_translation_short_text_translator_agent",
  "ai_translation_backfill_hourly_rate",
  "ai_translation_category_scope",
  "ai_translation_categories",
  "ai_translation_personal_messages",
  "ai_translation_include_bot_content",
  "ai_translation_backfill_start_date",
  "ai_translation_verbose_logs",
];

function createSetting(attrs) {
  return SiteSetting.create({
    setting: attrs.setting,
    humanized_name: attrs.setting,
    description: "",
    type: "string",
    value: null,
    default: null,
    ...attrs,
  });
}

module("Unit | Lib | ai-translation-settings", function (hooks) {
  setupTest(hooks);

  test("keeps every setting the translation page used to own", function (assert) {
    for (const name of PREVIOUSLY_GROUPED_SETTINGS) {
      assert.true(
        TRANSLATION_SETTING_NAMES.includes(name),
        `${name} is still on the translations page`
      );
    }

    assert.true(
      TRANSLATION_SETTING_NAMES.includes(
        "content_localization_supported_locales"
      ),
      "the supported languages setting is included"
    );
    assert.false(
      TRANSLATION_SETTING_NAMES.includes("ai_translation_enabled"),
      "the AI flag is rendered by the page header, not the form"
    );
  });

  test("every setting in the groups has a translated label", function (assert) {
    for (const name of TRANSLATION_SETTING_NAMES) {
      const definition = translationSettingDefinition(
        createSetting({ setting: name })
      );

      assert.strictEqual(
        definition.label,
        i18n(`discourse_ai.translations.settings.${name}.label`),
        `${name} uses the translations page copy`
      );
      assert.notStrictEqual(definition.label, "", `${name} has a label`);
    }
  });

  test("offers a setting only once what it requires is on", function (assert) {
    assert.true(
      translationSettingAvailable("content_localization_language_switcher", {
        allow_user_locale: true,
      }),
      "the language switcher needs users to choose a language"
    );
    assert.false(
      translationSettingAvailable("content_localization_language_switcher", {
        allow_user_locale: false,
      }),
      "no switcher without user locales"
    );
    assert.false(
      translationSettingAvailable("set_locale_from_param", {
        allow_user_locale: false,
      }),
      "language links need users to choose a language"
    );
    assert.true(
      translationSettingAvailable("content_localization_crawler_param", {
        allow_user_locale: true,
        set_locale_from_param: true,
      }),
      "indexing follows language links"
    );
    assert.false(
      translationSettingAvailable("content_localization_crawler_param", {
        allow_user_locale: false,
        set_locale_from_param: true,
      }),
      "the requirement chain is followed transitively"
    );
    assert.true(
      translationSettingAvailable("ai_translation_personal_messages", {}),
      "settings without requirements are always available"
    );
  });

  test("hides settings whose dependencies the form values do not meet", function (assert) {
    const settings = [
      createSetting({ setting: "ai_translation_category_scope", value: "all" }),
      createSetting({
        setting: "ai_translation_categories",
        depends_behavior: "hidden",
        depends_on: ["ai_translation_category_scope"],
        depends_on_values: {
          ai_translation_category_scope: ["include", "exclude"],
        },
      }),
      createSetting({
        setting: "allow_user_locale",
        type: "bool",
        value: true,
      }),
      createSetting({
        setting: "content_localization_language_switcher",
        value: "none",
      }),
    ];

    assert.false(
      translationSettingVisible(settings, settings[1], {
        ai_translation_category_scope: "all",
      }),
      "the category list is hidden for a scope that does not use it"
    );
    assert.true(
      translationSettingVisible(settings, settings[1], {
        ai_translation_category_scope: "include",
      }),
      "the category list is shown for a scope that uses it"
    );
    assert.true(
      translationSettingVisible(settings, settings[3], {
        allow_user_locale: true,
      }),
      "the language switcher is visible when available"
    );
    assert.false(
      translationSettingVisible(settings, settings[3], {
        allow_user_locale: false,
      }),
      "the language switcher is hidden when it would be rejected"
    );
  });

  test("translates choice labels for the page", function (assert) {
    const setting = createSetting({
      setting: "ai_translation_personal_messages",
      type: "enum",
      valid_values: ["none", "group", "all"],
    });

    assert.deepEqual(
      translationSettingDefinition(setting).valid_values,
      ["none", "group", "all"].map((value) => ({
        value,
        name: i18n(
          `discourse_ai.translations.settings.ai_translation_personal_messages.choices.${value}`
        ),
      })),
      "choices keep their values with page-specific names"
    );
  });

  test("groups keep their declared order", function (assert) {
    assert.deepEqual(
      TRANSLATION_SETTING_GROUPS.map((group) => group.key),
      ["languages", "scope", "backfill", "readers", "agents", "advanced"],
      "sections render in a stable order"
    );
  });
});
