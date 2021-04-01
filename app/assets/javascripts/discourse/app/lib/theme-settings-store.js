import { get } from "@ember/object";

const settings = {};

export function registerSettings(themeId, settingsObject) {
  settings[themeId] = settingsObject;
}

export function getSetting(themeId, settingsKey) {
  if (settings[themeId]) {
    return get(settings[themeId], settingsKey);
  }
  return null;
}

export function getObjectForTheme(themeId) {
  return settings[themeId];
}
