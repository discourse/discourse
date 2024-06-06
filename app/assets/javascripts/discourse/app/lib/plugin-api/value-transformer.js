import { isTesting } from "discourse-common/config/environment";

// add core transformer names
const validCoreTransformerNames = new Set(["header-notifications-avatar-size"]);

// do not add anything directly to this set, use addTransformerName instead
const validPluginTransformerNames = new Set();

const transformersRegistry = new Map();

/**
 * Indicates if the registry is open for registration.
 *
 * When the registry is closed, the system accepts adding new transformer names and throws an error when trying to
 * register a transformer.
 *
 * When the registry is open, the system will throw an error if a transformer name is added and will accept registering
 * transformers to be applied.
 *
 * @type {boolean}
 */
let registryOpened = false;

/**
 * Freezes the valid transformers list and open the registry to accept new transform registrations.
 *
 * INTERNAL API: to be used only in `initializers/freeze-valid-transformers`
 */
export function _freezeValidTransformerNames() {
  registryOpened = true;
}

/**
 * Apply a transformer to a value
 *
 * @param {string} transformerName the name of the transformer applied
 * @param {*} defaultValue the default value
 * @param {*} [context] the optional context to pass to the transformer callbacks.
 *
 * @returns {*} the transformed value
 */
export function applyTransformer(transformerName, defaultValue, context) {
  if (!transformerNameExists(transformerName)) {
    throw new Error(
      `applyTransformer: transformer name "${transformerName}" does not exist. Did you forget to register it?`
    );
  }

  const transformers = transformersRegistry.get(transformerName);
  if (!transformers) {
    return defaultValue;
  }

  let newValue = defaultValue;

  const transformerPoolSize = transformers.length;
  for (let i = 0; i < transformerPoolSize; i++) {
    const valueCallback = transformers[i];
    newValue = valueCallback({ value: newValue, context });
  }

  return newValue;
}

/**
 * Register a value transformer.
 *
 * INTERNAL API: use pluginApi.registerTransformer instead.
 *
 * @param {string} transformerName the name of the transformer
 * @param {function({value, context})} valueCallback callback that will transform the value.
 */
export function _registerTransformer(transformerName, valueCallback) {
  if (!registryOpened) {
    throw new Error(
      "api.registerTransformer was called while the system was still accepting new transformer names to be added.\n" +
        `Move your code to an initializer or a pre-initializer that runs after "freeze-valid-transformers" to avoid this error.`
    );
  }

  if (!transformerNameExists.has(transformerName)) {
    // eslint-disable-next-line no-console
    console.warn(
      `api.registerTransformer: transformer "${transformerName}" is unknown and will be ignored. ` +
        "Perhaps you misspelled it?"
    );
  }

  if (typeof valueCallback !== "function") {
    throw new Error(
      "api.registerTransformer requires the valueCallback argument to be a function"
    );
  }

  const existingTransformers = transformersRegistry.get(transformerName) || [];

  existingTransformers.push(valueCallback);

  transformersRegistry.set(transformerName, existingTransformers);
}

/**
 * Registers a new transformer name.
 *
 * INTERNAL API: use pluginApi.addTransformerName instead.
 *
 * DO NOT USE THIS FUNCTION TO ADD CORE TRANSFORMER NAMES. Instead register them directly in the
 * validCoreTransformerNames set above.
 *
 * @param {string} name the name to register
 */
export function _addTransformerName(name) {
  if (registryOpened) {
    throw new Error(
      "api.registerTransformer was called when the system is no longer accepting new names to be added.\n" +
        `Move your code to a pre-initializer that runs before "freeze-valid-transformers" to avoid this error.`
    );
  }

  if (validCoreTransformerNames.has(name)) {
    // eslint-disable-next-line no-console
    console.warn(
      `api.addTransformerName: transformer "${name}" matches an existing core transformer and shouldn't be re-registered using the the API.`
    );
    return;
  }

  if (validPluginTransformerNames.has(name)) {
    // eslint-disable-next-line no-console
    console.warn(
      `api.addTransformerName: transformer "${name}" is already registered.`
    );
    return;
  }

  if (transformersRegistry.size > 0) {
    throw new Error(
      `api.addTransformerName was called after transformers were registered.\n` +
        "This is not recommended as it can lead to unexpected behavior." +
        `If a plugin or theme component tried to register a transformer for "${name}" previously, the register was ignored.` +
        "Consider moving the call to addTransformerName to a pre-initializer."
    );
  }

  validPluginTransformerNames.add(name);
}

/**
 * Check if a transformer name exists
 *
 * @param {string} name the name to check
 * @returns {boolean}
 */
function transformerNameExists(name) {
  return (
    validCoreTransformerNames.has(name) || validPluginTransformerNames.has(name)
  );
}

/**
 * Resets the transformer names added.
 *
 * Use only for testing purposes.
 */
export function resetTransformerNames() {
  if (isTesting()) {
    validPluginTransformerNames.clear();
  }
}

/**
 * Resets the transformer names added.
 *
 * Use only for testing purposes.
 */
export function resetTransformers() {
  if (isTesting()) {
    transformersRegistry.clear();
  }
}
