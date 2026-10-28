import SiteSetting, {
  type SettingMetadata,
  type SettingValue,
  type SiteSettingFields,
} from "discourse/admin/models/site-setting";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

/** Theme translations reuse the setting model with only key, value, default and textarea. */
export interface ThemeSettingsFields extends SiteSettingFields {
  resolve_group_membership?: boolean;
}

/** The update endpoint returns a map keyed by the setting name. */
export type ThemeSettingUpdateResult = Record<string, SettingValue>;

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface ThemeSettings extends ThemeSettingsFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class ThemeSettings extends SiteSetting {
  /** The catch handles synchronous throws only; request rejections propagate to the caller. */
  updateSetting(
    themeId: number,
    newValue: SettingValue
  ): Promise<ThemeSettingUpdateResult | undefined>;

  updateSetting(this: never, id: string | number, value: SettingValue): never;
  async updateSetting(
    themeId: string | number,
    newValue: SettingValue
  ): Promise<ThemeSettingUpdateResult | undefined> {
    if (this.objects_schema) {
      newValue = JSON.stringify(newValue);
    }

    try {
      return ajax(`/admin/themes/${themeId}/setting`, {
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

  loadMetadata(themeId: number): Promise<SettingMetadata | void> {
    return ajax(
      `/admin/themes/${themeId}/objects_setting_metadata/${this.setting}.json`
    )
      .then((result: SettingMetadata) => this.set("metadata", result))
      .catch(popupAjaxError);
  }
}
