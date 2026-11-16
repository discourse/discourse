const DEDICATED_SETTINGS_ROUTES = {
  spam: "adminPlugins.show.discourse-ai-spam",
  translation: "adminPlugins.show.discourse-ai-translations",
};

/**
 * The admin page that owns a module's settings, for modules that have one
 * instead of the generic feature settings page.
 *
 * @param {string} moduleName
 * @returns {string | undefined}
 */
export function dedicatedSettingsRoute(moduleName) {
  return DEDICATED_SETTINGS_ROUTES[moduleName];
}
