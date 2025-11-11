import { createSiteSettingsFromPreloaded } from "discourse/services/site-settings";

const CLIENT_SETTING_TEST_OVERRIDES = {
  title: "QUnit Discourse Tests",
  site_logo_url: "/assets/logo.png",
  site_logo_small_url: "/assets/logo-single.png",
  site_mobile_logo_url: "",
  site_favicon_url: "/images/discourse-logo-sketch-small.png",
  enable_twitter_logins: true,
  enable_facebook_logins: true,
  enable_github_logins: true,
  authorized_extensions: "jpg|jpeg|png|gif|heic|heif|webp|svg|txt|ico|yml",
  anon_polling_interval: 30000,
};

import CLIENT_SITE_SETTINGS_WITH_DEFAULTS from "virtual:discourse-test-site-settings";
const ORIGINAL_CLIENT_SITE_SETTINGS = {
  ...CLIENT_SITE_SETTINGS_WITH_DEFAULTS,
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
