import { getSetting as getThemeSetting } from "discourse/lib/theme-settings-store";
import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("theme-setting", themeSetting);
export default function themeSetting(themeId, key) {
  return getThemeSetting(themeId, key);
}
