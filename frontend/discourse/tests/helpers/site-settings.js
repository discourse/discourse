import PreloadStore from "discourse/lib/preload-store";
import { createSiteSettingsFromPreloaded } from "discourse/services/site-settings";

const CLIENT_SETTING_TEST_OVERRIDES = {
  title: "QUnit Discourse Tests",
  site_logo_url: "/images/discourse-logo-sketch.png",
  site_logo_small_url: "/images/discourse-logo-sketch-small.png",
  site_mobile_logo_url: "",
  site_favicon_url: "/images/discourse-logo-sketch-small.png",
  enable_twitter_logins: true,
  enable_facebook_logins: true,
  enable_github_logins: true,
  authorized_extensions: "jpg|jpeg|png|gif|heic|heif|webp|svg|txt|ico|yml",
  anon_polling_interval: 30000,
};

const ORIGINAL_CLIENT_SITE_SETTINGS = {
  ...PreloadStore.get("siteSettings"),
  ...PreloadStore.get("themeSiteSettingOverrides"),
  ...CLIENT_SETTING_TEST_OVERRIDES,
};

let siteSettings;

export function currentSettings() {
  return siteSettings;
}

export function mergeSettings(other) {
  for (const key of Object.keys(other)) {
    siteSettings[key] = other[key];
  }

  return siteSettings;
}

export function resetSettings() {
  siteSettings = createSiteSettingsFromPreloaded(ORIGINAL_CLIENT_SITE_SETTINGS);
  return siteSettings;
}
