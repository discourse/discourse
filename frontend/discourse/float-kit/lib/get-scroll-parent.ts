import type { VirtualElement } from "@floating-ui/dom";

export function getScrollParent(
  node: Node | VirtualElement | null
): HTMLElement | Window | null {
  const isElement = node instanceof HTMLElement;
  const overflowY = isElement && window.getComputedStyle(node).overflowY;
  const isScrollable = overflowY !== "visible" && overflowY !== "hidden";

  if (!node || node === document.documentElement) {
    return null;
  } else if (
    isScrollable &&
    (node as HTMLElement).scrollHeight >= (node as HTMLElement).clientHeight
  ) {
    return node as HTMLElement;
  }

  // A virtual reference has no `parentNode`, so this recurses into the `?? window`
  // fallback for it, matching the untyped original.
  return getScrollParent((node as Node).parentNode) || window;
}
