import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import PreloadStore from "discourse/lib/preload-store";

@disableImplicitInjections
export default class SiteSettingsService {
  static isServiceFactory = true;

  static create() {
    const settings = new TrackedObject(PreloadStore.get("siteSettings"));

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
}
