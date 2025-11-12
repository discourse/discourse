/**
 * Greater than or equal helper
 * @param {unknown} left - First value to compare
 * @param {unknown} right - Second value to compare
 * @param {object} [options] - Options
 * @param {boolean} [options.forceNumber=false] - Force number conversion
 * @returns {boolean} Whether left is greater than or equal to right
 */
export default function gte(left, right, { forceNumber = false } = {}) {
  if (forceNumber) {
    if (typeof left !== "number") {
      left = Number(left);
    }
    if (typeof right !== "number") {
      right = Number(right);
    }
  }
  return left >= right;
}
