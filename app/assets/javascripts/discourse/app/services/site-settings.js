import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import PreloadStore from "discourse/lib/preload-store";

export function createSiteSettingsFromPreloaded(
  siteSettings,
  themeSiteSettingOverrides
) {
  const settings = new TrackedObject(siteSettings);

  // TODO (martin) Maybe we have some way of logging these overrides? Maybe
  // adding a key like `settings.themeSiteSettingOverrides` with this object?
  for (const [key, value] of Object.entries(themeSiteSettingOverrides)) {
    if (settings[key]) {
      settings[key] = value;
    }
  }

  settings.groupSettingArray = (groupSetting) => {
    const setting = settings[groupSetting];
    if (!setting) {
      return [];
    }

    return setting
      .toString()
      .split("|")
      .filter(Boolean)
      .map((groupId) => parseInt(groupId, 10));
  };

  return settings;
}

@disableImplicitInjections
export default class SiteSettingsService {
  static isServiceFactory = true;

  static create() {
    return createSiteSettingsFromPreloaded(
      PreloadStore.get("siteSettings"),
      PreloadStore.get("themeSiteSettingOverrides")
    );
  }
}
