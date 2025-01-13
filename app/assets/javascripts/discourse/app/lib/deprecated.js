import DEPRECATION_WORKFLOW from "../deprecation-workflow";

const handlers = [];
const disabledDeprecations = new Set();

let emberDeprecationSilencer;

/**
 * Display a deprecation warning with the provided message. The warning will be prefixed with the theme/plugin name
 * if it can be automatically determined based on the current stack.
 * @param {String} msg The deprecation message
 * @param {Object} [options] Deprecation options
 * @param {String} [options.id] A unique identifier for this deprecation. This should be namespaced by dots (e.g. discourse.my_deprecation)
 * @param {String} [options.since] The Discourse version this deprecation was introduced in
 * @param {String} [options.dropFrom] The Discourse version this deprecation will be dropped in. Typically one major version after `since`
 * @param {String} [options.url] A URL which provides more detail about the deprecation
 * @param {boolean} [options.raiseError] Raise an error when this deprecation is triggered. Defaults to `false`
 */
export default function deprecated(msg, options = {}) {
  const { id, since, dropFrom, url, raiseError } = options;

  if (id && disabledDeprecations.has(id)) {
    return;
  }

  msg = ["Deprecation notice:", msg];
  if (since) {
    msg.push(`[deprecated since Discourse ${since}]`);
  }
  if (dropFrom) {
    msg.push(`[removal in Discourse ${dropFrom}]`);
  }
  if (id) {
    msg.push(`[deprecation id: ${id}]`);
  }
  if (url) {
    msg.push(`[info: ${url}]`);
  }
  msg = msg.join(" ");

  let consolePrefix = "";
  if (require.has("discourse/lib/source-identifier")) {
    // This module doesn't exist in pretty-text/wizard/etc.
    consolePrefix =
      require("discourse/lib/source-identifier").consolePrefix() || "";
  }

  handlers.forEach((h) => h(msg, options));

  const matchedWorkflow = DEPRECATION_WORKFLOW.find((w) => w.matchId === id);

  if (
    raiseError ||
    matchedWorkflow?.handler === "throw" ||
    (!matchedWorkflow && globalThis.EmberENV?.RAISE_ON_DEPRECATION)
  ) {
    throw msg;
  }

  if (matchedWorkflow?.handler !== "silence") {
    console.warn(...[consolePrefix, msg].filter(Boolean)); //eslint-disable-line no-console
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
 * @param {(string|string[])} deprecationIds A single id, or an array of ids, of deprecations to silence
 * @param {function} callback The function to call while deprecations are silenced.
 */
export function withSilencedDeprecations(deprecationIds, callback) {
  ensureEmberDeprecationSilencer();
  const idArray = [].concat(deprecationIds);
  try {
    idArray.forEach((id) => disabledDeprecations.add(id));
    const result = callback();
    if (result instanceof Promise) {
      throw new Error(
        "withSilencedDeprecations callback returned a promise. Use withSilencedDeprecationsAsync instead."
      );
    }
    return result;
  } finally {
    idArray.forEach((id) => disabledDeprecations.delete(id));
  }
}

/**
 * Silence one or more deprecations while running an async `callback`
 * @async
 * @param {(string|string[])} deprecationIds A single id, or an array of ids, of deprecations to silence
 * @param {function} callback The asynchronous function to call while deprecations are silenced.
 */
export async function withSilencedDeprecationsAsync(deprecationIds, callback) {
  ensureEmberDeprecationSilencer();
  const idArray = [].concat(deprecationIds);
  try {
    idArray.forEach((id) => disabledDeprecations.add(id));
    return await callback();
  } finally {
    idArray.forEach((id) => disabledDeprecations.delete(id));
  }
}

function ensureEmberDeprecationSilencer() {
  if (emberDeprecationSilencer) {
    return;
  }

  emberDeprecationSilencer = (message, options, next) => {
    if (options?.id && disabledDeprecations.has(options.id)) {
      return;
    } else {
      next(message, options);
    }
  };

  if (require.has("@ember/debug")) {
    require("@ember/debug").registerDeprecationHandler(
      emberDeprecationSilencer
    );
  }
}
