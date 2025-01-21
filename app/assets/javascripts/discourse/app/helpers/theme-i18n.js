import { registerRawHelper } from "discourse/lib/helpers";
import { i18n } from "discourse-i18n";

registerRawHelper("theme-i18n", themeI18n);
export default function themeI18n(themeId, key, params) {
  if (typeof themeId !== "number") {
    throw new Error(
      `The theme-i18n helper is not supported in this context.\n\n` +
        `In a theme .gjs file, use '{{i18n (themePrefix "${themeId}")}}' instead.\n\n` +
        `'themePrefix' is available automatically, and does not need to be imported.\n`
    );
  }
  return i18n(`theme_translations.${themeId}.${key}`, params);
}
