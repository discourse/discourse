import { registerDeprecationHandler as emberRegisterDeprecationHandler } from "@ember/debug";
import DeprecationWorkflow from "../deprecation-workflow";
import { isRailsTesting } from "./environment";
import { consolePrefix } from "./source-identifier";

const handlers = [];
const disabledDeprecations = [];

let emberDeprecationSilencer;

/**
 * Display a deprecation warning with the provided message. The warning will be prefixed with the theme/plugin name
 * if it can be automatically determined based on the current stack.
 *
 * @param {String} msg The deprecation message
 * @param {Object} [options] Deprecation options
 * @param {String} [options.id] A unique identifier for this deprecation. This should be namespaced by dots (e.g. discourse.my_deprecation)
 * @param {String} [options.since] The Discourse version this deprecation was introduced in
 * @param {String} [options.dropFrom] The Discourse version this deprecation will be dropped in. Typically one major version after `since`
 * @param {String} [options.url] A URL which provides more detail about the deprecation
 * @param {boolean} [options.raiseError] Raise an error when this deprecation is triggered. Defaults to `false`
 */
export default function deprecated(msg, options = {}) {
  const { id, source } = options;

  // deprecations explicitly silenced in code using withSilencedDeprecations or
  // withSilencedDeprecationsAsync.
  // These deprecations should not be logged or raised as error because the code that
  // generates them is handled manually. It can be for example a fallback routine
  if (isDeprecationSilenced(id)) {
    return;
  }

  const raiseError =
    options.raiseError ||
    DeprecationWorkflow.shouldThrow(
      id,
      globalThis.EmberENV?.RAISE_ON_DEPRECATION
    );

  const formattedMessage = buildDeprecationMessage(msg, options, raiseError);
  const resolvedConsolePrefix = getConsolePrefix(source);

  // Execute all registered deprecation handlers
  handlers.forEach((h) => h(formattedMessage, options));

  if (!DeprecationWorkflow.shouldSilence(id)) {
    if (raiseError) {
      raiseDeprecationError(resolvedConsolePrefix, formattedMessage);
    }

    console.warn(...[resolvedConsolePrefix, formattedMessage].filter(Boolean)); //eslint-disable-line no-console
  }
}
/**
 * Register a function which will be called whenever a deprecation is triggered
 * @param {function} callback The callback function. Arguments will match those of `deprecated()`.
 */
export function registerDeprecationHandler(callback) {
  handlers.push(callback);
}

/**
 * Silence one or more deprecations while running `callback`
 * @param {(string|RegExp|Array<string|RegExp>)} deprecationIds A single id, regex pattern, or an array containing a mix of ids and regex patterns to silence
 * @param {function} callback The function to call while deprecations are silenced.
 */
export function withSilencedDeprecations(deprecationIds, callback) {
  ensureEmberDeprecationSilencer();
  const idArray = [].concat(deprecationIds);
  try {
    idArray.forEach((id) => disabledDeprecations.push(id));
    const result = callback();
    if (result instanceof Promise) {
      throw new Error(
        "withSilencedDeprecations callback returned a promise. Use withSilencedDeprecationsAsync instead."
      );
    }
    return result;
  } finally {
    idArray.forEach(() => disabledDeprecations.pop());
  }
}

/**
 * Silence one or more deprecations while running an async `callback`
 * @async
 * @param {(string|RegExp|Array<string|RegExp>)} deprecationIds A single id, regex pattern, or an array containing a mix of ids and regex patterns to silence
 * @param {function} callback The asynchronous function to call while deprecations are silenced.
 */
export async function withSilencedDeprecationsAsync(deprecationIds, callback) {
  ensureEmberDeprecationSilencer();
  const idArray = [].concat(deprecationIds);
  try {
    idArray.forEach((id) => disabledDeprecations.push(id));
    return await callback();
  } finally {
    idArray.forEach(() => disabledDeprecations.pop());
  }
}

/**
 * Checks if a given deprecation ID is currently silenced
 * @param {String} id The deprecation id to check
 * @returns {boolean} True if the deprecation is silenced, false otherwise
 */
export function isDeprecationSilenced(id) {
  return (
    id &&
    disabledDeprecations.length &&
    disabledDeprecations.find((disabledId) => {
      if (disabledId instanceof RegExp) {
        return disabledId.test(id);
      }

      return disabledId === id;
    })
  );
}

/**
 * Ensures the Ember deprecation silencer is registered with Ember's debug system.
 * This function sets up a deprecation handler that intercepts Ember deprecations
 * and respects the silencing configuration from disabledDeprecations.
 *
 * The silencer is only registered once, and only if the @ember/debug module is available.
 */
function ensureEmberDeprecationSilencer() {
  if (emberDeprecationSilencer) {
    return;
  }

  emberDeprecationSilencer = (message, options, next) => {
    if (!isDeprecationSilenced(options?.id)) {
      next(message, options);
    }
  };

  emberRegisterDeprecationHandler(emberDeprecationSilencer);
}

/**
 * Builds the formatted deprecation message with all the metadata
 *
 * @param {String} msg The base deprecation message
 * @param {Object} options Deprecation options
 * @param {boolean} raiseError Whether this is a fatal deprecation
 * @returns {String} The formatted message
 */
function buildDeprecationMessage(msg, options, raiseError) {
  const { id, since, dropFrom, url } = options;
  const parts = [
    raiseError ? "FATAL DEPRECATION:" : "DEPRECATION NOTICE:",
    msg,
  ];

  if (since) {
    parts.push(`[deprecated since Discourse ${since}]`);
  }
  if (dropFrom) {
    parts.push(`[removal in Discourse ${dropFrom}]`);
  }
  if (id) {
    parts.push(`[deprecation id: ${id}]`);
  }
  if (url) {
    parts.push(`[info: ${url}]`);
  }

  return parts.join(" ");
}

/**
 * Gets the console prefix for the deprecation message
 *
 * @param {String} source Optional source identifier
 * @returns {String} The console prefix
 */
function getConsolePrefix(source) {
  consolePrefix(null, source) || "";
}

/**
 * Raises a deprecation error with additional context for Rails testing
 *
 * @param {String} resolvedConsolePrefix The console prefix
 * @param {String} message The full deprecation message
 */
function raiseDeprecationError(resolvedConsolePrefix, message) {
  const error = new Error(
    [resolvedConsolePrefix, message].filter(Boolean).join(" ")
  );

  if (isRailsTesting()) {
    // eslint-disable-next-line no-console
    console.trace(`fatal_deprecation:${JSON.stringify(error.stack)}`);
  }

  throw error;
}
