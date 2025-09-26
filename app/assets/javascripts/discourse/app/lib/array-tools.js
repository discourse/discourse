import {
  beginPropertyChanges,
  endPropertyChanges,
} from "@ember/-internals/metal";
import { TrackedArray } from "@ember-compat/tracked-built-ins";

function _removeValue(array, value) {
  let loc = array.length || 0;
  while (--loc >= 0) {
    if (array[loc] === value) {
      array.splice(loc, 1);
    }
  }
  return array;
}

/**
 * Removes all occurrences of a specified value from an array.
 *
 * @param {Array} array - The array from which the value needs to be removed.
 * @param {*} value - The value to be removed from the array.
 * @return {Array} The modified array with the specified value removed.
 */
export function removeObject(array, value) {
  if (array instanceof TrackedArray) {
    beginPropertyChanges();
    _removeValue(array, value);
    endPropertyChanges();
  } else {
    _removeValue(array, value);
  }

  return array;
}
