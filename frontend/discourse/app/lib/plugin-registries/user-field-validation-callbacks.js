export const customUserFieldValidationCallbacks = [];

export function addCustomUserFieldValidationCallback(callback) {
  customUserFieldValidationCallbacks.push(callback);
}
