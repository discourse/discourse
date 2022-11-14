const handlers = [];
const disabledDeprecations = new Set();

/**
 * Display a deprecation warning with the provided message. The warning will be prefixed with the theme/plugin name
 * if it can be automatically determined based on the current stack.
 * @param {String} msg The deprecation message
 * @param {Object} options
 * @param {String} [options.id] A unique identifier for this deprecation. This should be namespaced by dots (e.g. discourse.my_deprecation)
 * @param {String} [options.since] The Discourse version this deprecation was introduced in
 * @param {String} [options.dropFrom] The Discourse version this deprecation will be dropped in. Typically one major version after `since`
 * @param {String} [options.url] A URL which provides more detail about the deprecation
 * @param {boolean} [options.raiseError] Raise an error when this deprecation is triggered. Defaults to `false`
 */
export default function deprecated(msg, options) {
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

  if (raiseError) {
    throw msg;
  }

  let consolePrefix = "";
  if (window.Discourse) {
    // This module doesn't exist in pretty-text/wizard/etc.
    consolePrefix =
      require("discourse/lib/source-identifier").consolePrefix() || "";
  }

  console.warn(consolePrefix, msg); //eslint-disable-line no-console

  handlers.forEach((h) => h(msg, options));
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
 * @async
 * @param {(string|string[])} deprecationIds A single id, or an array of ids, of deprecations to silence
 * @param {function} callback The function to call while deprecations are silenced. Can be asynchronous.
 */
export async function withSilencedDeprecations(deprecationIds, callback) {
  try {
    Array(deprecationIds).forEach((id) => disabledDeprecations.add(id));
    return await callback();
  } finally {
    Array(deprecationIds).forEach((id) => disabledDeprecations.delete(id));
  }
}
