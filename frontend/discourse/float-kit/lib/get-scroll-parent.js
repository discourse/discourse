export function getScrollParent(node) {
  const isElement = node instanceof HTMLElement;
  const overflowY = isElement && window.getComputedStyle(node).overflowY;
  const isScrollable = overflowY !== "visible" && overflowY !== "hidden";

  if (!node || node === document.documentElement) {
    return null;
  } else if (isScrollable && node.scrollHeight >= node.clientHeight) {
    return node;
  }

  return getScrollParent(node.parentNode) || window;
}
