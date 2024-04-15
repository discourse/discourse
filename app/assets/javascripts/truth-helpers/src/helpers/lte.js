export default function lte(left, right, { forceNumber = false } = {}) {
  if (forceNumber) {
    if (typeof left !== "number") {
      left = Number(left);
    }
    if (typeof right !== "number") {
      right = Number(right);
    }
  }
  return left <= right;
}
