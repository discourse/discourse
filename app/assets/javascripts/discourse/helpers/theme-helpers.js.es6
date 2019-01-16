import { registerUnbound } from "discourse-common/lib/helpers";
import deprecated from "discourse-common/lib/deprecated";

registerUnbound("theme-i18n", (themeId, key, params) => {
  return I18n.t(`theme_translations.${themeId}.${key}`, params);
});

registerUnbound(
  "theme-prefix",
  (themeId, key) => `theme_translations.${themeId}.${key}`
);

registerUnbound("theme-setting", (themeId, key, hash) => {
  if (hash.deprecated) {
    deprecated(
      "The `{{themeSetting.setting_name}}` syntax is deprecated. Use `{{theme-setting 'setting_name'}}` instead",
      { since: "v2.2.0.beta8", dropFrom: "v2.3.0" }
    );
  }
  return Discourse.__container__
    .lookup("service:theme-settings")
    .getSetting(themeId, key);
});
