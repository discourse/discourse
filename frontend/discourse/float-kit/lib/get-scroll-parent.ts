import type { VirtualElement } from "@floating-ui/dom";

export function getScrollParent(
  node: Node | VirtualElement | null
): HTMLElement | Window | null {
  if (!node) {
    return null;
  }

  if (!("nodeType" in node)) {
    return node.contextElement?.ownerDocument.defaultView ?? null;
  }

  return scrollParentForNode(node, node.ownerDocument);
}

function scrollParentForNode(
  node: Node | null,
  ownerDocument: Document
): HTMLElement | Window | null {
  const defaultView = ownerDocument.defaultView;
  const isElement = Boolean(
    node?.nodeType === Node.ELEMENT_NODE &&
    (node as Element).namespaceURI === "http://www.w3.org/1999/xhtml"
  );
  const overflowY =
    isElement && defaultView?.getComputedStyle(node as HTMLElement).overflowY;
  const isScrollable = overflowY !== "visible" && overflowY !== "hidden";

  if (!node || node === ownerDocument.documentElement) {
    return null;
  } else if (
    isScrollable &&
    (node as HTMLElement).scrollHeight >= (node as HTMLElement).clientHeight
  ) {
    return node as HTMLElement;
  }

  return scrollParentForNode(node.parentNode, ownerDocument) || defaultView;
}
