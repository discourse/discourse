import { get } from "@ember/object";
import { TrackedArray } from "@ember-compat/tracked-built-ins";

/**
 * Adds a value to the array if it does not already exist in the array.
 *
 * @param {Array} target - The array to check and add the value to.
 * @param {*} value - The value to add to the array if it doesn't already exist.
 * @param {Function} [selector] - Optional function used to transform each value for uniqueness comparison.
 * If undefined, strict equality comparison will be used.
 * @return {Array} The updated array containing the value if it was not already present.
 * @example
 * // Using simple value comparison
 * addUniqueValueToArray([1, 2], 3) // returns [1, 2, 3]
 * addUniqueValueToArray([1, 2], 2) // returns [1, 2]
 *
 * // Using selector function
 * const arr = [{id: 1}, {id: 2}];
 * addUniqueValueToArray(arr, {id: 3}, (item) => item.id) // adds object with id 3
 */
export function addUniqueValueToArray(target, value, selector) {
  const uniqByValue = selector && selector(value);
  const exists = selector
    ? target.some((item) => selector(item) === uniqByValue)
    : target.includes(value);
  if (!exists) {
    target.push(value);
  }

  return target;
}

/**
 * Adds multiple values to the specified array only if they do not already exist in the array.
 * This function iterates through the provided values and ensures each value is checked and added individually.
 *
 * @param {Array} target - The array to which values will be added if they do not already exist.
 * @param {Array} values - The array of values to check and add to the target array if they are not present.
 * @param {Function} [selector] - Optional function used to transform each value for uniqueness comparison.
 * If undefined, strict equality comparison will be used.
 * @throws {TypeError} When target or values parameters are not arrays.
 * @return {void} This function does not return a value; it directly modifies the input array.
 */
export function addUniqueValuesToArray(target, values, selector) {
  if (!Array.isArray(target)) {
    throw new TypeError("addUniqueValuesToArray: 'target' must be an array");
  }
  if (!Array.isArray(values)) {
    throw new TypeError("addUniqueValuesToArray: 'values' must be an array");
  }

  for (const value of values) {
    addUniqueValueToArray(target, value, selector);
  }
}

/**
 * Removes all occurrences of a specified value from an array.
 *
 * @param {Array} target - The array from which the value needs to be removed.
 * @param {*} value - The value to be removed from the array.
 * @return {Array} The modified array with the specified value removed.
 */
export function removeValueFromArray(target, value) {
  if (!Array.isArray(target)) {
    throw new TypeError("removeValueFromArray: 'target' must be an array");
  }

  let loc = target.length || 0;
  while (--loc >= 0) {
    if (target[loc] === value) {
      target.splice(loc, 1);
    }
  }
  return target;
}

/**
 * Removes multiple objects from an array by iterating through the provided values
 * and removing each value from the given array.
 *
 * @param {Array} target - The array from which objects will be removed.
 * @param {Array} values - An array of objects to be removed from the given array.
 * @return {Array} The updated array with specified objects removed.
 */
export function removeValuesFromArray(target, values) {
  for (let i = values.length - 1; i >= 0; i--) {
    removeValueFromArray(target, values[i]);
  }

  return target;
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
