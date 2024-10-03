let pluginHeaderActionComponents = new Map();

export function registerPluginHeaderActionComponent(pluginId, componentClass) {
  pluginHeaderActionComponents.set(pluginId, componentClass);
}

export function clearPluginHeaderActionComponents() {
  pluginHeaderActionComponents = new Map();
}

export function headerActionComponentForPlugin(pluginId) {
  return pluginHeaderActionComponents.get(pluginId);
}
