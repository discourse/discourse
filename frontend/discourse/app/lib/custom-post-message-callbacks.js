let customPostMessageCallbacks = {};

export function resetCustomPostMessageCallbacks() {
  customPostMessageCallbacks = {};
}

export function registerCustomPostMessageCallback(type, callback) {
  if (customPostMessageCallbacks[type]) {
    throw new Error(`Error ${type} is an already registered post message!`);
  }

  customPostMessageCallbacks[type] = callback;
}

export function dispatchCustomPostMessageCallback(type, controller, message) {
  const callback = customPostMessageCallbacks[type];

  if (!callback) {
    return false;
  }

  callback(controller, message);
  return true;
}
