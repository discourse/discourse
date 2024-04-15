import { registerRawHelper } from "discourse-common/lib/helpers";
import I18n from "discourse-i18n";

registerRawHelper("theme-i18n", themeI18n);
export default function themeI18n(themeId, key, params) {
  return I18n.t(`theme_translations.${themeId}.${key}`, params);
}
