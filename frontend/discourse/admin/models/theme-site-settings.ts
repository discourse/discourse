import SiteSetting, {
  type SettingValue,
  type SiteSettingFields,
} from "discourse/admin/models/site-setting";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

/** Themeable site settings retain the endpoint's string values. */
export interface ThemeSiteSettingsFields extends SiteSettingFields {
  value: string;
  default: string;
}

/** Resetting an override can return only the success marker. */
export type ThemeSiteSettingUpdateResult = { success: "OK" } & (
  | { name: string; value: string | null; theme_id: number }
  | { name?: never; value?: never; theme_id?: never }
);

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface ThemeSiteSettings extends ThemeSiteSettingsFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class ThemeSiteSettings extends SiteSetting {
  declare value: string;
  declare default: string;

  /** The catch handles synchronous throws only; request rejections propagate to the caller. */
  updateSetting(
    themeId: number,
    newValue: string
  ): Promise<ThemeSiteSettingUpdateResult | undefined>;

  updateSetting(this: never, id: string | number, value: SettingValue): never;
  async updateSetting(
    themeId: string | number,
    newValue: SettingValue
  ): Promise<ThemeSiteSettingUpdateResult | undefined> {
    try {
      return ajax(`/admin/themes/${themeId}/site-setting`, {
        type: "PUT",
        data: {
          name: this.setting,
          value: newValue,
        },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
