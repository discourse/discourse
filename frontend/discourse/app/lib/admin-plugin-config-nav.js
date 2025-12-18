let pluginConfigNav = {};
export function registerAdminPluginConfigNav(pluginId, links) {
  pluginConfigNav[pluginId] = { links };
}
export function resetAdminPluginConfigNav() {
  pluginConfigNav = {};
}
export function configNavForPlugin(pluginId) {
  return pluginConfigNav[pluginId];
}
