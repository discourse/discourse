import { i18n } from "discourse-i18n";

export function availableCategoryType(type) {
  if (!type.available) {
    return false;
  } else if (type.required_plugin && !type.can_enable_plugin) {
    return false;
  }
  return true;
}

export function unavailableBadgeText(type) {
  if (type.required_plugin) {
    return i18n("category.choose_type.requires_plugin", {
      plugin_name: type.required_plugin,
    });
  }
  return i18n("category.choose_type.unavailable");
}

export function showAskAdminMessage(type) {
  return type.required_plugin && !type.can_enable_plugin;
}

export function askAdminToEnablePluginText(type) {
  return i18n("category.choose_type.ask_admin_to_enable_plugin", {
    plugin_name: type.required_plugin,
  });
}
