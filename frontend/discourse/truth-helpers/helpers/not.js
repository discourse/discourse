import truthConvert from "../utils/truth-convert";

/**
 * Logical NOT helper - returns false if any arg is truthy, true otherwise
 * @param {...unknown} args - Values to evaluate
 * @returns {boolean} False if any arg is truthy, true otherwise
 */
export default function not(...args) {
  for (let arg of args) {
    if (truthConvert(arg) === true) {
      return false;
    }
  }

  return true;
}
