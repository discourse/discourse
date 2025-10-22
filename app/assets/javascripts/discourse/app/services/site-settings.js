import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import PreloadStore from "discourse/lib/preload-store";
import i18n from "discourse-i18n";

export function createSiteSettingsFromPreloaded(
  siteSettings,
  themeSiteSettingOverrides
) {
  const settings = new TrackedObject(siteSettings);

  if (themeSiteSettingOverrides) {
    for (const [key, value] of Object.entries(themeSiteSettingOverrides)) {
      settings[key] = value;
    }
    settings.themeSiteSettingOverrides = themeSiteSettingOverrides;
  }

  // localize locale names here as they are not localized in the backend
  // due to initialization order and caching
  if (settings.available_locales) {
    const locales = JSON.parse(settings.available_locales);
    const localizedLocales = locales.map(({ native_name, value, name }) => {
      const localized_name = i18n.t(name);
      const displayName =
        localized_name && localized_name !== native_name
          ? `${localized_name} (${native_name})`
          : native_name;
      return { value, name: displayName };
    });

    settings.available_locales = localizedLocales;
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
