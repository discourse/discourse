import truthConvert from "../utils/truth-convert";

/**
 * Logical OR helper - returns first truthy value or last value
 * @param {...unknown} args - Values to evaluate
 * @returns {unknown} First truthy value or last value
 */
export default function or(...args) {
  let arg = false;

  for (arg of args) {
    if (truthConvert(arg) === true) {
      return arg;
    }
  }

  return arg;
}
