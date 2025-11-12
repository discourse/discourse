import truthConvert from "../utils/truth-convert";

/**
 * Logical AND helper - returns first falsy value or last value
 * @param {...unknown} args - Values to evaluate
 * @returns {unknown} First falsy value or last value
 */
export default function and(...args) {
  let arg = false;

  for (arg of args) {
    if (truthConvert(arg) === false) {
      return arg;
    }
  }

  return arg;
}
