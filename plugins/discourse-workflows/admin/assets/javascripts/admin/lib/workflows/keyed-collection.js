// Helpers for object-valued parameters where a present key means "set" and an
// absent key means "leave alone", so removing an entry must delete its key.

/**
 * Whether the value is a plain object of keyed entries.
 *
 * @param {any} value
 * @returns {boolean}
 */
export function isKeyedValue(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

/**
 * Returns the value when it is a plain object, otherwise an empty object.
 *
 * @param {any} value
 * @returns {object}
 */
export function keyedValue(value) {
  return isKeyedValue(value) ? value : {};
}

/**
 * Returns a copy of the keyed value without the `name` entry.
 *
 * @param {object} value
 * @param {string} name
 * @returns {object}
 */
export function withoutKey(value, name) {
  const nextValue = { ...value };
  delete nextValue[name];
  return nextValue;
}
