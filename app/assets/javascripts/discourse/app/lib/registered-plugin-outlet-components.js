export const registeredPluginOutletComponents = {};

export function registerPluginOutletComponents(outletName, component) {
  registeredPluginOutletComponents[outletName] ||= [];
  registeredPluginOutletComponents[outletName].push(component);
}

export function clearRegisteredPluginOutletComponents() {
  registeredPluginOutletComponents = {};
}
