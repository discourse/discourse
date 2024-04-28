export const PLUGIN_NAV_MODE_SIDEBAR = "sidebar";
export const PLUGIN_NAV_MODE_TOP = "top";
let pluginConfigNav = {};
export function registerAdminPluginConfigNav(pluginId, mode, links) {
  pluginConfigNav[pluginId] = { mode, links };
}
export function resetAdminPluginConfigNav() {
  pluginConfigNav = {};
}
export function configNavForPlugin(pluginId) {
  return pluginConfigNav[pluginId];
}
