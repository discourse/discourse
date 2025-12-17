let pluginConfigNav = {};
let pluginIcons = {};

export function registerAdminPluginConfigNav(pluginId, links) {
  pluginConfigNav[pluginId] = { links };
}

export function registerAdminPluginIcon(pluginId, icon) {
  pluginIcons[pluginId] = icon;
}

export function resetAdminPluginConfigNav() {
  pluginConfigNav = {};
  pluginIcons = {};
}

export function configNavForPlugin(pluginId) {
  return pluginConfigNav[pluginId];
}

export function iconForPlugin(pluginId) {
  return pluginIcons[pluginId];
}
