import { TrackedObject } from "tracked-built-ins";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import PreloadStore from "discourse/lib/preload-store";

export function createSiteSettingsFromPreloaded(data) {
  const settings = new TrackedObject(data);

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
    return createSiteSettingsFromPreloaded(PreloadStore.get("siteSettings"));
  }
}
