let pluginConfigNav = {};
export function registerAdminPluginConfigNav(pluginId, links, icon) {
  pluginConfigNav[pluginId] = { links, icon };
}
export function resetAdminPluginConfigNav() {
  pluginConfigNav = {};
}
export function configNavForPlugin(pluginId) {
  return pluginConfigNav[pluginId];
}
