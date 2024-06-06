// add core transformer names
const validCoreTransformerNames = new Set(["header-notifications-avatar-size"]);

// do not add anything directly to this set, use addTransformerName instead
const validPluginTransformerNames = new Set();

const transformersRegistry = new Map();

/**
 * Register a value transformer. To be used by the plugin API.
 *
 * @param {string} transformerName the name of the transformer
 * @param {* | function} valueOrCallback the value or callback to apply. If a callback is provided, it will be called
 * with the following arguments: { newValue, context }
 */
export function registerTransformer(transformerName, valueOrCallback) {
  if (!transformerNameExists.has(transformerName)) {
    // eslint-disable-next-line no-console
    console.warn(
      `api registerTransformer: transformer "${transformerName}" is unknown and will be ignored.`
    );
  }

  if (valueOrCallback === undefined) {
    throw new Error(
      "api registerTransformer requires transformer to be set with a value or a callback"
    );
  }

  const existingTransformers = transformersRegistry.get(transformerName) || [];

  existingTransformers.push({
    valueOrCallback,
    isCallback: typeof valueOrCallback === "function", // to avoid unnecessary checks while applying the transformer
  });

  transformersRegistry.set(transformerName, existingTransformers);
}

/**
 * Apply a transformer to a value
 *
 * @param {string} transformerName the name of the transformer applied
 * @param {*} defaultValue the default value
 * @param {*} [context] the context to pass to the transformer callbacks
 *
 * @returns {*} the transformed value
 */

export function applyTransformer(transformerName, defaultValue, context) {
  if (!transformerNameExists(transformerName)) {
    throw new Error(
      `applyTransformer: transformer id "${transformerName}" does not exist. Did you forget to register it?`
    );
  }

  const transformers = transformersRegistry.get(transformerName);
  if (!transformers) {
    return defaultValue;
  }

  let newValue = defaultValue;

  const transformerPoolSize = transformers.length;
  for (let i = 0; i < transformerPoolSize; i++) {
    const { valueOrCallback, isCallback } = transformers[i];

    if (isCallback) {
      newValue = valueOrCallback({ value: newValue, context });
    } else {
      newValue = valueOrCallback;
    }
  }

  return newValue;
}

/**
 * Register a transformer name.
 *
 * To be used only in the plugin API. Do not use this functions to add core transformer names. Instead register them
 * directly in the validCoreTransformerNames set above.
 *
 * @param {string} name the name to register
 */
export function addTransformerName(name) {
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
    // eslint-disable-next-line no-console
    console.warn(
      `api.addTransformerName was called after transformers were registered.\n` +
        "This is not recommended as it can lead to unexpected behavior." +
        `If a plugin or theme component tried to register a transformer for "${name}" previously, the register was ignored.` +
        "Consider moving the call to addTransformerName to a pre-initializer."
    );
    return;
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

// to be used only for test purposes
export function clearTransformerNames() {
  validPluginTransformerNames.clear();
}

// to be used only for test purposes
export function clearTransformers() {
  transformersRegistry.clear();
}
