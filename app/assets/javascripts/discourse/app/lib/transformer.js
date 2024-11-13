import { DEBUG } from "@glimmer/env";
import { capitalize } from "@ember/string";
import { consolePrefix } from "discourse/lib/source-identifier";
import {
  BEHAVIOR_TRANSFORMERS,
  VALUE_TRANSFORMERS,
} from "discourse/lib/transformer/registry";
import { isTesting } from "discourse-common/config/environment";

const CORE_TRANSFORMER = "CORE";
const PLUGIN_TRANSFORMER = "PLUGIN";

export const transformerTypes = Object.freeze({
  // key and value must match
  BEHAVIOR: "BEHAVIOR",
  VALUE: "VALUE",
});

/**
 * Test flag - disables throwing an exception if applying a transformer fails on tests
 *
 * @type {boolean}
 */
let skipApplyExceptionOnTests = false;

/**
 * Valid core transformer names initialization.
 *
 * Some checks are performed to ensure there are no repeated names between the multiple transformer types.
 *
 * The list can be edited in `discourse/lib/transformer/registry`
 */
let validTransformerNames = new Map();

// Initialize the valid transformer names, notice that we perform some checks to ensure the transformer names are
// correctly defined, i.e., lowercase and unique.
[
  [BEHAVIOR_TRANSFORMERS, transformerTypes.BEHAVIOR],
  [VALUE_TRANSFORMERS, transformerTypes.VALUE],
].forEach(([list, transformerType]) => {
  list.forEach((name) => {
    if (DEBUG) {
      if (name !== name.toLowerCase()) {
        throw new Error(
          `Transformer name "${name}" must be lowercase. Found in ${transformerType} transformers.`
        );
      }

      const existingInfo = findTransformerInfoByName(name);

      if (existingInfo) {
        const candidateName = `${name}/${transformerType.toLowerCase()}`;

        throw new Error(
          `Transformer name "${candidateName}" can't be added. The transformer ${existingInfo.name} already exists.`
        );
      }
    }

    validTransformerNames.set(
      _normalizeTransformerName(name, transformerType),
      CORE_TRANSFORMER
    );
  });
});

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
 * INTERNAL API: use pluginApi.addValueTransformerName or pluginApi.addBehaviorTransformerName instead.
 *
 * DO NOT USE THIS FUNCTION TO ADD CORE TRANSFORMER NAMES. Instead register them directly in the
 * validTransformerNames set above.
 *
 * @param {string} name the name to register
 * @param {string} transformerType the type of the transformer being added
 */
export function _addTransformerName(name, transformerType) {
  const prefix = `${consolePrefix()} api.add${capitalize(
    transformerType.toLowerCase()
  )}TransformerName`.trim();

  if (name !== name.toLowerCase()) {
    throw new Error(`${prefix}: transformer name "${name}" must be lowercase.`);
  }

  if (registryOpened) {
    throw new Error(
      `${prefix} was called when the system is no longer accepting new names to be added. ` +
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
      `${prefix}: transformer "${name}" matches existing core transformer "${existingInfo.name}" and shouldn't be re-registered using the the API.`
    );
    return;
  }

  // eslint-disable-next-line no-console
  console.warn(
    `${prefix}: transformer "${existingInfo.name}" is already registered`
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
 * @returns {boolean} True if the transformer exists, false otherwise.
 */
export function _registerTransformer(
  transformerName,
  transformerType,
  callback
) {
  if (!transformerTypes[transformerType]) {
    throw new Error(`Invalid transformer type: ${transformerType}`);
  }
  const prefix = `${consolePrefix()} api.register${capitalize(
    transformerType.toLowerCase()
  )}Transformer`.trim();

  if (!registryOpened) {
    throw new Error(
      `${prefix} was called while the system was still accepting new transformer names to be added.\n` +
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
      `${prefix}: transformer "${transformerName}" is unknown and will be ignored. ` +
        "Is the name correct? Are you using the correct API for the transformer type?"
    );

    return false;
  }

  if (typeof callback !== "function") {
    throw new Error(
      `${prefix} requires the callback argument to be a function`
    );
  }

  const existingTransformers =
    transformersRegistry.get(normalizedTransformerName) || [];

  existingTransformers.push(callback);

  transformersRegistry.set(normalizedTransformerName, existingTransformers);

  return true;
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

  const prefix = `${consolePrefix()} applyBehaviorTransformer`.trim();

  if (!transformerNameExists(normalizedTransformerName)) {
    throw new Error(
      `${prefix}: transformer name "${transformerName}" does not exist. ` +
        "Was the transformer name properly added? Is the transformer name correct? Is the type equals BEHAVIOR? " +
        "applyBehaviorTransformer can only be used with BEHAVIOR transformers."
    );
  }

  if (typeof defaultCallback !== "function") {
    throw new Error(
      `${prefix} requires the callback argument to be a function`
    );
  }

  if (
    typeof (context ?? undefined) !== "undefined" &&
    !(typeof context === "object" && context.constructor === Object)
  ) {
    throw `${prefix}("${transformerName}", ...): context must be a simple JS object or nullish.`;
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

    // do not surround the default implementation in the try ... catch block
    if (currentCallback === defaultCallback) {
      return currentCallback({ context: appliedContext });
    }

    try {
      return currentCallback({ context: appliedContext, next: nextCallback });
    } catch (error) {
      document.dispatchEvent(
        new CustomEvent("discourse-error", {
          detail: { messageKey: "broken_transformer_alert", error },
        })
      );

      if (isTesting() && !skipApplyExceptionOnTests) {
        throw error;
      }

      // if the current callback failed keep processing the callback queue
      // hopefully the application won't be left in a broken state
      return nextCallback();
    }
  }

  return nextCallback();
}

/**
 * Apply a transformer to a value.
 *
 * @param {string} transformerName - The name of the transformer applied
 * @param {*} defaultValue - The default value
 * @param {*} [context] - The optional context to pass to the transformer callbacks
 * @param {Object} [opts] - Options for the transformer
 * @param {boolean} [opts.mutable] - Flag indicating if the value should be mutated instead of returned
 * @returns {*} The transformed value
 * @throws {Error} If the transformer name does not exist or the context is invalid
 */
export function applyValueTransformer(
  transformerName,
  defaultValue,
  context,
  opts = { mutable: false }
) {
  const normalizedTransformerName = _normalizeTransformerName(
    transformerName,
    transformerTypes.VALUE
  );

  const prefix = `${consolePrefix()} applyValueTransformer`.trim();

  if (!transformerNameExists(normalizedTransformerName)) {
    throw new Error(
      `${prefix}: transformer name "${transformerName}" does not exist. ` +
        "Was the transformer name properly added? Is the transformer name correct? Is the type equals VALUE? " +
        "applyValueTransformer can only be used with VALUE transformers."
    );
  }

  if (
    typeof (context ?? undefined) !== "undefined" &&
    !(typeof context === "object" && context.constructor === Object)
  ) {
    throw (
      `${prefix}("${transformerName}", ...): context must be a simple JS object or nullish.\n` +
      "Avoid passing complex objects in the context, like for example, component instances or objects that carry " +
      "mutable state directly. This can induce users to registry transformers with callbacks causing side effects " +
      "and mutating the context directly. Inevitably, this leads to fragile integrations."
    );
  }

  const transformers = transformersRegistry.get(normalizedTransformerName);

  if (!transformers) {
    return defaultValue;
  }

  const mutable = opts?.mutable; // flag indicating if the value should be mutated instead of returned
  let newValue = defaultValue;

  const transformerPoolSize = transformers.length;
  for (let i = 0; i < transformerPoolSize; i++) {
    const valueCallback = transformers[i];

    try {
      const value = valueCallback({ value: newValue, context });
      if (mutable && typeof value !== "undefined") {
        throw new Error(
          `${prefix}: transformer "${transformerName}" expects the value to be mutated instead of returned. Remove the return value in your transformer.`
        );
      }

      if (!mutable) {
        newValue = value;
      }
    } catch (error) {
      document.dispatchEvent(
        new CustomEvent("discourse-error", {
          detail: { messageKey: "broken_transformer_alert", error },
        })
      );

      if (isTesting() && !skipApplyExceptionOnTests) {
        throw error;
      }
    }
  }

  return newValue;
}

/**
 * Apply a transformer to a mutable value.
 * The registered transformers should mutate the value instead of returning it.
 *
 * @param {string} transformerName - The name of the transformer applied
 * @param {*} defaultValue - The default value
 * @param {*} [context] - The optional context to pass to the transformer callbacks
 * @returns {*} The transformed value
 * @throws {Error} If the transformer name does not exist or the context is invalid
 */
export function applyMutableValueTransformer(
  transformerName,
  defaultValue,
  context
) {
  return applyValueTransformer(transformerName, defaultValue, context, {
    mutable: true,
  });
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
  acceptNewTransformerNames();
  transformersRegistry.clear();
  skipApplyExceptionOnTests = false;
}

/**
 * Clears all transformer names registered using the plugin API
 */
function clearPluginTransformers() {
  validTransformerNames = new Map(
    [...validTransformerNames].filter(([, type]) => type === CORE_TRANSFORMER)
  );
}

/**
 * Disables throwing the exception when applying the transformers in a test environment
 *
 * It's only to test if the exception in handled properly
 *
 * USE ONLY FOR TESTING PURPOSES.
 */
export function disableThrowingApplyExceptionOnTests() {
  skipApplyExceptionOnTests = true;
}
