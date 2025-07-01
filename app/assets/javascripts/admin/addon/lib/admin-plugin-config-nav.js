import { applyValueTransformer } from "discourse/lib/transformer";

export function configNavForPlugin(pluginId) {
  const navs = {};
  applyValueTransformer("admin-plugin-config-navs", {}, null, {
    mutable: true,
  });
  return navs[pluginId];
}
