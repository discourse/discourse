import { registerUnbound } from "discourse-common/lib/helpers";
import I18n from "I18n";
import { getSetting as getThemeSetting } from "discourse/lib/theme-settings-store";

export function themeI18n(themeId, key, params) {
  return I18n.t(`theme_translations.${themeId}.${key}`, params);
}
registerUnbound("theme-i18n", themeI18n);

export function themePrefix(themeId, key) {
  return `theme_translations.${themeId}.${key}`;
}
registerUnbound("theme-prefix", themePrefix);

export function themeSetting(themeId, key) {
  return getThemeSetting(themeId, key);
}
registerUnbound("theme-setting", themeSetting);
