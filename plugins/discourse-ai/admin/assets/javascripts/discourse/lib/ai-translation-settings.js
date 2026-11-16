import { isSettingValueTrue } from "discourse/admin/models/site-setting";
import { i18n } from "discourse-i18n";
import { isSettingVisible } from "./site-settings-form.js";

export const TRANSLATION_SETTING_GROUPS = [
  {
    key: "languages",
    settings: ["content_localization_supported_locales"],
  },
  {
    key: "scope",
    settings: [
      "ai_translation_category_scope",
      "ai_translation_categories",
      "ai_translation_personal_messages",
      "ai_translation_include_bot_content",
    ],
  },
  {
    key: "backfill",
    settings: [
      "ai_translation_backfill_start_date",
      "ai_translation_backfill_hourly_rate",
    ],
  },
  {
    key: "readers",
    settings: [
      "content_localization_enabled",
      "allow_user_locale",
      "content_localization_language_switcher",
      "set_locale_from_param",
      "content_localization_crawler_param",
      "content_localization_use_default_locale_when_unsupported",
    ],
  },
  {
    key: "agents",
    settings: [
      "ai_translation_locale_detector_agent",
      "ai_translation_locale_detector_decision_model",
      "ai_translation_post_raw_translator_agent",
      "ai_translation_topic_title_translator_agent",
      "ai_translation_short_text_translator_agent",
    ],
  },
  {
    key: "advanced",
    settings: ["ai_translation_verbose_logs"],
  },
];

// Settings that are rejected unless another setting on this page is on, so they
// are only offered once it is.
const REQUIRED_SETTINGS = {
  content_localization_language_switcher: "allow_user_locale",
  set_locale_from_param: "allow_user_locale",
  content_localization_crawler_param: "set_locale_from_param",
};

/**
 * @param {string} name
 * @param {Object} data - the form data
 */
export function translationSettingAvailable(name, data) {
  const required = REQUIRED_SETTINGS[name];
  return (
    !required ||
    (isSettingValueTrue(data[required]) &&
      translationSettingAvailable(required, data))
  );
}

/**
 * Whether the translations page renders the setting, and so whether its form
 * value may be submitted.
 *
 * @param {SiteSetting[]} settings
 * @param {SiteSetting} setting
 * @param {Object} data - the form data
 */
export function translationSettingVisible(settings, setting, data) {
  return (
    isSettingVisible(settings, setting, data) &&
    translationSettingAvailable(setting.setting, data)
  );
}

export const TRANSLATION_SETTING_NAMES = TRANSLATION_SETTING_GROUPS.flatMap(
  (group) => group.settings
);

const CHOICES = {
  ai_translation_personal_messages: ["none", "group", "all"],
  content_localization_language_switcher: ["none", "anonymous", "all"],
};

/**
 * The setting's definition with labels written for the translations page, since
 * the site setting names and descriptions refer to other settings by name.
 *
 * @param {SiteSetting} setting
 */
export function translationSettingDefinition(setting) {
  const copy = `discourse_ai.translations.settings.${setting.setting}`;
  const definition = {
    ...setting.definition,
    label: i18n(`${copy}.label`),
    description: i18n(`${copy}.description`),
  };

  const choices = CHOICES[setting.setting];
  if (choices) {
    definition.valid_values = choices.map((value) => ({
      value,
      name: i18n(`${copy}.choices.${value}`),
    }));
  }

  return definition;
}
