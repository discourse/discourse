import { get } from "@ember/object";
import { cloneJSON } from "discourse/lib/object";

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
  originalSettings[themeId] = cloneJSON(settingsObject);
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
      const original = originalSettings[themeId][key];
      if (original && typeof original === "object") {
        // special handling for the theme_uploads and theme_uploads_local magic
        // objects in settings
        settings[themeId][key] = cloneJSON(original);
      } else {
        settings[themeId][key] = original;
      }
    });
  });
}
