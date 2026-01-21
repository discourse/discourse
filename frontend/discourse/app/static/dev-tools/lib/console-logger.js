/**
 * Shared console logging utility for dev tools.
 *
 * Provides consistent argument logging to console with a persistent counter
 * that increments across all dev tools components during the session.
 *
 * @module discourse/static/dev-tools/lib/console-logger
 */

/**
 * Counter for generating unique global variable names.
 * Persists across all dev-tools components for the session.
 *
 * @type {number}
 */
let globalArgCounter = 1;

/**
 * Console output styles for dev tools logging.
 */
const STYLES = {
  varName: "color: #ce6edf; font-weight: bold",
  keyName: "color: #46a7f5",
  reset: "",
};

/**
 * Logs a value to the console and saves it to a global variable.
 * The variable is named `arg1`, `arg2`, etc., incrementing for each call.
 *
 * @param {Object} options - Log options.
 * @param {string} options.key - The argument key/name being logged.
 * @param {any} options.value - The value to log and store globally.
 * @param {string} [options.prefix] - Optional prefix for context (e.g., "plugin outlet").
 * @returns {string} The variable name assigned (e.g., "arg1").
 */
export function logArgToConsole({ key, value, prefix }) {
  const varName = `arg${globalArgCounter++}`;

  // Warn if overwriting an existing global variable
  if (varName in window && window[varName] !== undefined) {
    // eslint-disable-next-line no-console
    console.warn(`DevTools: Overwriting existing global "${varName}"`);
  }

  window[varName] = value;

  const prefixStr = prefix ? `[${prefix}] ` : "";

  // eslint-disable-next-line no-console
  console.log(
    `${prefixStr}%c${key}%c saved to %c${varName}%c`,
    STYLES.keyName,
    STYLES.reset,
    STYLES.varName,
    STYLES.reset,
    value
  );

  return varName;
}

/**
 * Resets the global argument counter.
 * Primarily for testing purposes.
 */
export function resetArgCounter() {
  globalArgCounter = 1;
}

/**
 * Gets the current counter value without incrementing.
 * Useful for displaying what the next variable name will be.
 *
 * @returns {number} The current counter value.
 */
export function getNextArgNumber() {
  return globalArgCounter;
}
