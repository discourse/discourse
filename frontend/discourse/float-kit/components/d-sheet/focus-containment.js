import { getFocusableElements } from "./focus-utils";

const CLONE_SELECTOR = "[data-d-sheet-clone]";

function createGuard() {
  const guard = document.createElement("div");
  guard.tabIndex = 0;
  guard.style.position = "fixed";
  guard.setAttribute("aria-hidden", "true");
  guard.setAttribute("data-d-sheet", "focus-guard");
  return guard;
}

function containsElement(rootElements, element) {
  return rootElements.some(
    (rootElement) => rootElement === element || rootElement.contains(element)
  );
}

function focus(element) {
  element?.focus?.({ preventScroll: true });
}

function safelyFocusableElements(rootElements) {
  return rootElements.flatMap(
    (rootElement) => getFocusableElements(rootElement).safelyFocusableElements
  );
}

function safelyTabbableElements(rootElements) {
  return rootElements.flatMap(
    (rootElement) => getFocusableElements(rootElement).safelyTabbableElements
  );
}

export default function setupFocusContainment({
  rootElements,
  viewElement,
  getElementFocusedLast,
  setElementFocusedLast,
}) {
  const roots = rootElements.filter((element) => element?.isConnected);
  const guards = new Map();

  for (const rootElement of roots) {
    const before = createGuard();
    const after = createGuard();

    rootElement.insertAdjacentElement("beforebegin", before);
    rootElement.insertAdjacentElement("afterend", after);
    guards.set(before, -1);
    guards.set(after, 1);
  }

  const initialFocus = document.activeElement;
  if (initialFocus && containsElement(roots, initialFocus)) {
    setElementFocusedLast(initialFocus);
  }

  const focusFallback = () => {
    const focusedLast = getElementFocusedLast();
    if (focusedLast?.isConnected && containsElement(roots, focusedLast)) {
      focus(focusedLast);
      return;
    }

    focus(safelyTabbableElements(roots)[0] ?? viewElement ?? roots[0]);
  };

  const handleFocusIn = (event) => {
    const target = event.target;
    if (!(target instanceof Element) || target.matches(CLONE_SELECTOR)) {
      return;
    }

    const safelyFocusable = safelyFocusableElements(roots);
    if (roots.includes(target) || safelyFocusable.includes(target)) {
      setElementFocusedLast(target);
      return;
    }

    focusFallback();
  };

  const handleFocusOut = (event) => {
    const relatedTarget = event.relatedTarget;
    if (!(relatedTarget instanceof HTMLElement)) {
      return;
    }

    const direction = guards.get(relatedTarget);
    if (!direction) {
      return;
    }

    const tabbableElements = safelyTabbableElements(roots);
    if (tabbableElements.length === 0) {
      focus(viewElement ?? roots[0]);
      return;
    }

    const currentIndex = tabbableElements.indexOf(event.target);
    const nextIndex =
      currentIndex === -1
        ? direction > 0
          ? 0
          : tabbableElements.length - 1
        : (currentIndex + direction + tabbableElements.length) %
          tabbableElements.length;
    const target = tabbableElements[nextIndex];

    if (target === event.target) {
      event.preventDefault();
      event.stopPropagation();
      requestAnimationFrame(() => focus(target));
    } else {
      focus(target);
    }
  };

  const handleKeyDown = (event) => {
    if (
      event.key !== "Tab" ||
      (event.target instanceof Element && containsElement(roots, event.target))
    ) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();
    focusFallback();
  };

  document.addEventListener("keydown", handleKeyDown);
  document.addEventListener("focusout", handleFocusOut);
  document.addEventListener("focusin", handleFocusIn);

  let active = true;
  return {
    guardElements: [...guards.keys()],
    cleanup() {
      if (!active) {
        return;
      }

      active = false;
      document.removeEventListener("keydown", handleKeyDown);
      document.removeEventListener("focusout", handleFocusOut);
      document.removeEventListener("focusin", handleFocusIn);
      for (const guard of guards.keys()) {
        guard.remove();
      }
    },
  };
}
