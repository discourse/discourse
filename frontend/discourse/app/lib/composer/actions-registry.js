let registeredActions = [];

export function registerComposerAction(opts) {
  registeredActions.push(opts);
}

export function registeredComposerActions() {
  return registeredActions;
}

export function _clearRegisteredActions() {
  registeredActions = [];
}
