let pluginHeaderActionComponents = [];

export function registerPluginHeaderActionComponent(pluginId, componentKlass) {
  pluginHeaderActionComponents[pluginId] = componentKlass;
}

export function clearPluginHeaderActionComponents() {
  pluginHeaderActionComponents = {};
}

export function headerActionComponentForPlugin(pluginId) {
  return pluginHeaderActionComponents[pluginId];
}
