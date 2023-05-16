let saveAttrsForControllerMap = null;

export function resetPreferencesControllersSaveAttrs() {
  saveAttrsForControllerMap = null;
}

export function addSaveAttributeToPreferencesController(
  controllerName,
  attribute
) {
  saveAttrsForControllerMap ||= {};
  saveAttrsForControllerMap[controllerName] ||= [];
  saveAttrsForControllerMap[controllerName].push(attribute);
}

export function getSaveAttributeForPreferencesController(controllerName) {
  return (saveAttrsForControllerMap || {})[controllerName] || [];
}
