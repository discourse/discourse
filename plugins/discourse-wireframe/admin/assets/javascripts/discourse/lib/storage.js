// @ts-check

/**
 * Reads a boolean preference from `localStorage`. Swallows access exceptions
 * (private browsing, strict cookie settings) and returns the default, so the
 * editor degrades gracefully when storage isn't usable.
 *
 * @param {string} key
 * @param {boolean} [defaultValue=false]
 * @returns {boolean}
 */
export function readBoolStorage(key, defaultValue = false) {
  try {
    const value = localStorage.getItem(key);
    if (value === null) {
      return defaultValue;
    }
    return value === "true";
  } catch {
    return defaultValue;
  }
}

/**
 * Persists a boolean preference. Same swallow-and-no-op fallback as the reader.
 *
 * @param {string} key
 * @param {boolean} value
 */
export function writeBoolStorage(key, value) {
  try {
    localStorage.setItem(key, value ? "true" : "false");
  } catch {
    /* no-op */
  }
}
