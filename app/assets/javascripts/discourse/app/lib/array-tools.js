import { get } from "@ember/object";
import { TrackedArray } from "@ember-compat/tracked-built-ins";

/**
 * Removes all occurrences of a specified value from an array.
 *
 * @param {Array} array - The array from which the value needs to be removed.
 * @param {*} value - The value to be removed from the array.
 * @return {Array} The modified array with the specified value removed.
 */
export function removeValueFromArray(array, value) {
  let loc = array.length || 0;
  while (--loc >= 0) {
    if (array[loc] === value) {
      array.splice(loc, 1);
    }
  }
  return array;
}

/**
 * Normalizes the selector argument into a callable function.
 * @param {(string|number|Function)} selector
 * @returns {Function}
 * @throws {Error} when selector type is invalid
 */
function buildSelector(selector) {
  switch (typeof selector) {
    case "number":
      return (item) => item[selector];
    case "string":
      return selector.includes(".")
        ? (item) => get(item, selector)
        : (item) => item[selector];
    case "function":
      return selector;
    default:
      throw new Error(
        "uniqueItemsFromArray: the `selector` argument must be a string/number key " +
        `or a function, got ${typeof selector} instead`
      );
  }
}

/**
 * Returns a new array with unique items based on the provided selector function.
 * @param {Array} array
 * @param {Function} selectorFn
 * @returns {Array}
 */
function dedupeBy(array, selectorFn) {
  const uniqueKeys = new Set();
  const result = [];
  for (const item of array) {
    const key = selectorFn(item);
    if (!uniqueKeys.has(key)) {
      uniqueKeys.add(key);
      result.push(item);
    }
  }
  return result;
}

/**
 * Returns a new array containing the unique elements from the input array.
 * Elements are determined to be unique based on either strict equality or a specified condition.
 *
 * @param {Array} array - The input array from which unique elements are to be extracted.
 * Must be a valid array. An error is thrown if the input is not an array.
 * @param {(string|number|Function)} [selector] - Optional selector to determine uniqueness:
 * - If undefined: uses strict equality comparison
 * - If string/number: uses the value at the specified object property path
 * - If function: uses the return value of the function called with each item
 * @throws {Error} If array is not an Array or if selector is an invalid type
 * @return {Array|TrackedArray} A new array with only unique elements (TrackedArray if input was TrackedArray)
 */
export function uniqueItemsFromArray(array, selector) {
  if (!Array.isArray(array)) {
    throw new Error(
      `uniqueItemsFromArray expects an array as first argument, got ${typeof array} instead`
    );
  }

  const items =
    selector === undefined
      ? [...new Set(array)]
      : dedupeBy(array, buildSelector(selector));

  return array instanceof TrackedArray ? new TrackedArray(items) : items;
}
