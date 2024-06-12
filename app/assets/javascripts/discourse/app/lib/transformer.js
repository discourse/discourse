import { capitalize } from "@ember/string";
import {
  BEHAVIOR_TRANSFORMERS,
  VALUE_TRANSFORMERS,
} from "discourse/lib/transformer/registry";
import { isProduction, isTesting } from "discourse-common/config/environment";

const CORE_TRANSFORMER = "CORE";
const PLUGIN_TRANSFORMER = "PLUGIN";

export const transformerTypes = Object.freeze({
  // key and value must match
  BEHAVIOR: "BEHAVIOR",
  VALUE: "VALUE",
});

/**
 * Valid core transformer names initialization.
 *
 * Some checks are performed to ensure there are no repeated names between the multiple transformer types.
 *
 * The list can be edited in `discourse/lib/transformer/registry`
 */
let validTransformerNames;

// Initialize the valid transformer names, notice that this is a self-invoking function that performs some checks
// to ensure the transformer names are correctly defined, i.e., lowercase and unique.
// We're not assigning the result directly to `validTransformerNames` because we're using the function
// `findTransformerInfoByName` which relies on `validTransformerNames` being initialized.
(() => {
  const coreTransformers = new Map();

  [
    [BEHAVIOR_TRANSFORMERS, transformerTypes.BEHAVIOR],
    [VALUE_TRANSFORMERS, transformerTypes.VALUE],
  ].forEach(([list, transformerType]) => {
    list.forEach((name) => {
      if (name !== name.toLowerCase()) {
        throw new Error(
          `Transformer name "${name}" must be lowercase. Found in ${transformerType} transformers.`
        );
      }

      if (!isProduction()) {
        const existingInfo = findTransformerInfoByName(name);

        if (existingInfo) {
          const candidateName = `${name}/${transformerType.toLowerCase()}`;

          throw new Error(
            `Transformer name "${candidateName}" can't be added. The transformer ${existingInfo.name} already exists.`
          );
        }
      }

      coreTransformers.set(
        _normalizeTransformerName(name, transformerType),
        CORE_TRANSFORMER
      );
    });
  });

  validTransformerNames = coreTransformers;
})();

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

function _normalizeTransformerName(name, type) {
  return `${name}/${type.toLowerCase()}`;
}

/**
 * Adds a new valid transformer name.
 *
 * INTERNAL API: use pluginApi.addValueTransformerName instead.
 *
 * DO NOT USE THIS FUNCTION TO ADD CORE TRANSFORMER NAMES. Instead register them directly in the
 * validTransformerNames set above.
 *
 * @param {string} name the name to register
 * @param {string} transformerType the type of the transformer being added
 */
export function _addTransformerName(name, transformerType) {
  const apiName = `api.add${capitalize(
    transformerType.toLowerCase()
  )}TransformerName`;

  if (name !== name.toLowerCase()) {
    throw new Error(
      `${apiName}: transformer name "${name}" must be lowercase.`
    );
  }

  if (registryOpened) {
    throw new Error(
      `${apiName} was called when the system is no longer accepting new names to be added.` +
        `Move your code to a pre-initializer that runs before "freeze-valid-transformers" to avoid this error.`
    );
  }

  const existingInfo = findTransformerInfoByName(name);

  if (!existingInfo) {
    validTransformerNames.set(
      _normalizeTransformerName(name, transformerType),
      PLUGIN_TRANSFORMER
    );

    return;
  }

  if (existingInfo.source === CORE_TRANSFORMER) {
    // eslint-disable-next-line no-console
    console.warn(
      `${apiName}: transformer "${name}" matches existing core transformer "${existingInfo.name}" and shouldn't be re-registered using the the API.`
    );
    return;
  }

  // eslint-disable-next-line no-console
  console.warn(
    `${apiName}: transformer "${existingInfo.name}" is already registered`
  );
}

/**
 * Registers a transformer.
 *
 * INTERNAL API: use pluginApi.registerBehaviorTransformer or pluginApi.registerValueTransformer instead.
 *
 * @param {string} transformerName the name of the transformer
 * @param {string} transformerType the type of the transformer being registered
 * @param {function} callback callback that will transform the value.
 */
export function _registerTransformer(
  transformerName,
  transformerType,
  callback
) {
  if (!transformerTypes[transformerType]) {
    throw new Error(`Invalid transformer type: ${transformerType}`);
  }

  const apiName = `api.register${capitalize(
    transformerType.toLowerCase()
  )}Transformer`;

  if (!registryOpened) {
    throw new Error(
      `${apiName} was called while the system was still accepting new transformer names to be added.\n` +
        `Move your code to an initializer or a pre-initializer that runs after "freeze-valid-transformers" to avoid this error.`
    );
  }

  const normalizedTransformerName = _normalizeTransformerName(
    transformerName,
    transformerType
  );

  if (!transformerNameExists(normalizedTransformerName)) {
    // eslint-disable-next-line no-console
    console.warn(
      `${apiName}: transformer "${transformerName}" is unknown and will be ignored. ` +
        "Is the name correct? Are you using the correct API for the transformer type?"
    );
  }

  if (typeof callback !== "function") {
    throw new Error(
      `${apiName} requires the callback argument to be a function`
    );
  }

  const existingTransformers =
    transformersRegistry.get(normalizedTransformerName) || [];

  existingTransformers.push(callback);

  transformersRegistry.set(normalizedTransformerName, existingTransformers);
}

export function applyBehaviorTransformer(
  transformerName,
  defaultCallback,
  context
) {
  const normalizedTransformerName = _normalizeTransformerName(
    transformerName,
    transformerTypes.BEHAVIOR
  );

  if (!transformerNameExists(normalizedTransformerName)) {
    throw new Error(
      `applyBehaviorTransformer: transformer name "${transformerName}" does not exist.` +
        "Was the transformer name properly added? Is the transformer name correct? Is the type equals BEHAVIOR?" +
        "applyBehaviorTransformer can only be used with BEHAVIOR transformers."
    );
  }

  if (typeof defaultCallback !== "function") {
    throw new Error(
      `applyBehaviorTransformer requires the callback argument to be a function`
    );
  }

  if (
    typeof (context ?? undefined) !== "undefined" &&
    !(typeof context === "object" && context.constructor === Object)
  ) {
    throw `applyBehaviorTransformer("${transformerName}", ...): context must be a simple JS object or nullish.`;
  }

  const transformers = transformersRegistry.get(normalizedTransformerName);
  const appliedContext = { ...context };
  if (!appliedContext._unstable_self && this) {
    appliedContext._unstable_self = this;
  }

  if (!transformers) {
    return defaultCallback({ context: appliedContext });
  }

  const callbackQueue = [...transformers, defaultCallback];

  function nextCallback() {
    const currentCallback = callbackQueue.shift();

    if (!currentCallback) {
      return;
    }

    return currentCallback({ context: appliedContext, next: nextCallback });
  }

  return nextCallback();
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
export function applyValueTransformer(transformerName, defaultValue, context) {
  const normalizedTransformerName = _normalizeTransformerName(
    transformerName,
    transformerTypes.VALUE
  );

  if (!transformerNameExists(normalizedTransformerName)) {
    throw new Error(
      `applyValueTransformer: transformer name "${transformerName}" does not exist.` +
        "Was the transformer name properly added? Is the transformer name correct? Is the type equals VALUE?" +
        "applyValueTransformer can only be used with VALUE transformers."
    );
  }

  if (
    typeof (context ?? undefined) !== "undefined" &&
    !(typeof context === "object" && context.constructor === Object)
  ) {
    throw (
      `applyValueTransformer("${transformerName}", ...): context must be a simple JS object or nullish.\n` +
      "Avoid passing complex objects in the context, like for example, component instances or objects that carry " +
      "mutable state directly. This can induce users to registry transformers with callbacks causing side effects " +
      "and mutating the context directly. Inevitably, this leads to fragile integrations."
    );
  }

  const transformers = transformersRegistry.get(normalizedTransformerName);

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
 * @typedef {Object} TransformerInfo
 * @property {string} name - The normalized name of the transformer
 * @property {string} source - The source of the transformer
 */

/**
 * Find a transformer info by name, without considering the type
 *
 * @param name the name of the transformer
 *
 * @returns {TransformerInfo | null} info the transformer info or null if not found
 */
function findTransformerInfoByName(name) {
  for (const searchedType of Object.keys(transformerTypes)) {
    const searchedName = _normalizeTransformerName(name, searchedType);
    const source = validTransformerNames?.get(searchedName);

    if (source) {
      return { name: searchedName, source };
    }
  }

  return null;
}

/**
 * Check if a transformer name exists
 *
 * @param normalizedName the normalized name to check
 * @returns {boolean} true if the transformer name exists, false otherwise
 */
function transformerNameExists(normalizedName) {
  return validTransformerNames.has(normalizedName);
}

///////// Testing helpers

/**
 * Check if a transformer was added
 *
 * @param {string} name the name to check
 * @param {string} type the type of the transformer
 *
 * @returns {boolean} true if a transformer with the given name and type exists, false otherwise
 */
export function transformerWasAdded(name, type) {
  return validTransformerNames.has(_normalizeTransformerName(name, type));
}

/**
 * Stores the initial state of `registryOpened` to allow the correct reset after a test that needs to manually
 * override the registry opened state finishes running.
 *
 * @type {boolean | null}
 */
let testRegistryOpenedState = null; // initially set to null bto allow testing if it was initialized

/**
 * Opens the transformers registry for registration
 *
 * USE ONLY FOR TESTING PURPOSES.
 */
export function acceptNewTransformerNames() {
  if (!isTesting()) {
    throw new Error("Use `acceptNewTransformerNames` only in tests.");
  }

  if (testRegistryOpenedState === null) {
    testRegistryOpenedState = registryOpened;
  }

  registryOpened = false;
}

/**
 * Closes the transformers registry for registration
 *
 * USE ONLY FOR TESTING PURPOSES.
 */
export function acceptTransformerRegistrations() {
  if (!isTesting()) {
    throw new Error("Use `acceptTransformerRegistrations` only in tests.");
  }

  if (testRegistryOpenedState === null) {
    testRegistryOpenedState = registryOpened;
  }

  registryOpened = true;
}

/**
 * Resets the transformers initial state
 *
 * USE ONLY FOR TESTING PURPOSES.
 */
export function resetTransformers() {
  if (!isTesting()) {
    throw new Error("Use `resetTransformers` only in tests.");
  }

  if (testRegistryOpenedState !== null) {
    registryOpened = testRegistryOpenedState;
  }

  clearPluginTransformers();
  transformersRegistry.clear();
}

/**
 * Clears all transformer names registered using the plugin API
 */
function clearPluginTransformers() {
  validTransformerNames = new Map(
    [...validTransformerNames].filter(([, type]) => type === CORE_TRANSFORMER)
  );
}
