import { get } from "@ember/object";

const originalSettings = {};
const settings = {};

export function registerSettings(
  themeId,
  settingsObject,
  { force = false } = {}
) {
  if (settings[themeId] && !force) {
    return;
  }
  originalSettings[themeId] = Object.assign({}, settingsObject);
  const s = {};
  Object.keys(settingsObject).forEach((key) => {
    Object.defineProperty(s, key, {
      enumerable: true,
      get() {
        return settingsObject[key];
      },
      set(newVal) {
        settingsObject[key] = newVal;
      },
    });
  });
  settings[themeId] = s;
}

export function getSetting(themeId, settingKey) {
  if (settings[themeId]) {
    return get(settings[themeId], settingKey);
  }
  return null;
}

export function getObjectForTheme(themeId) {
  return settings[themeId];
}

export function resetSettings() {
  Object.keys(originalSettings).forEach((themeId) => {
    Object.keys(originalSettings[themeId]).forEach((key) => {
      settings[themeId][key] = originalSettings[themeId][key];
    });
  });
}
