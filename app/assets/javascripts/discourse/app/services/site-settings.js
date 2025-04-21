import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import PreloadStore from "discourse/lib/preload-store";

export function createSiteSettingsFromPreloaded(
  siteSettings,
  themeSiteSettingOverrides
) {
  const settings = new TrackedObject(siteSettings);

  if (themeSiteSettingOverrides) {
    for (const [key, value] of Object.entries(themeSiteSettingOverrides)) {
      settings[key] = value;
      // eslint-disable-next-line no-console
      console.info(
        `[Discourse] Overriding site setting ${key} with theme site setting value: ${value}`
      );
    }
    settings.themeSiteSettingOverrides = themeSiteSettingOverrides;
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
