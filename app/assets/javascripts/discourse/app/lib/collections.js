/*
  This returns all items of the left collection
  except items that are also present in the right collection.

  For example:
  except(["a", "b", "c", "d"], ["a", "b"]) returns ["c", "d"]
 */
export function except(left, right) {
  const result = [];
  const rightSet = new Set(right);
  for (const item of left) {
    if (!rightSet.has(item)) {
      result.push(item);
    }
  }
  return result;
}
