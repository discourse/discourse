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
 * Removes multiple objects from an array by iterating through the provided values
 * and removing each value from the given array.
 *
 * @param {Array} array - The array from which objects will be removed.
 * @param {Array} values - An array of objects to be removed from the given array.
 * @return {Array} The updated array with specified objects removed.
 */
export function removeValuesFromArray(array, values) {
  for (let i = values.length - 1; i >= 0; i--) {
    removeValueFromArray(array, values[i]);
  }

  return array;
}
