export let toolbarCallbacks = [];

export function addToolbarCallback(func) {
  toolbarCallbacks.push(func);
}

export function clearToolbarCallbacks() {
  toolbarCallbacks = [];
}
