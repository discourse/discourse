import { registerUnbound } from "discourse-common/lib/helpers";
import I18n from "I18n";
import deprecated from "discourse-common/lib/deprecated";
import { getSetting as getThemeSetting } from "discourse/lib/theme-settings-store";

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
      { since: "v2.2.0.beta8" }
    );
  }

  return getThemeSetting(themeId, key);
});
