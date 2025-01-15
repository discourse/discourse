import { registerRawHelper } from "discourse/lib/helpers";
import { getSetting as getThemeSetting } from "discourse/lib/theme-settings-store";

registerRawHelper("theme-setting", themeSetting);
export default function themeSetting(themeId, key) {
  if (typeof themeId !== "number") {
    throw new Error(
      `The theme-setting helper is not supported in this context.\n\n` +
        `In a theme .gjs file, use '{{settings.${themeId}}}' instead.\n\n` +
        `'settings' is available automatically, and does not need to be imported.\n`
    );
  }
  return getThemeSetting(themeId, key);
}
