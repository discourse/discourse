import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("theme-prefix", themePrefix);
export default function themePrefix(themeId, key) {
  return `theme_translations.${themeId}.${key}`;
}
