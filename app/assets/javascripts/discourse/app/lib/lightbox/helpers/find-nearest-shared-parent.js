export function findNearestSharedParent(items) {
  const ancestors = [];
  for (const item of items) {
    let ancestor = item;
    while (ancestor) {
      ancestors.push(ancestor);
      ancestor = ancestor.parentElement;
    }
  }
  return ancestors.filter(
    (ancestor) =>
      ancestors.indexOf(ancestor) !== ancestors.lastIndexOf(ancestor)
  )[0];
}
