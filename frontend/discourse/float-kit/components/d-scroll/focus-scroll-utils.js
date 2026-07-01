export function isColorOrSelect(element) {
  if (!element) {
    return false;
  }
  if (element instanceof HTMLInputElement && element.type === "color") {
    return true;
  }
  if (element instanceof HTMLSelectElement) {
    return true;
  }
  return false;
}
export function isPasswordRelatedInput(element) {
  if (!(element instanceof HTMLInputElement)) {
    return false;
  }
  if (element.type === "password") {
    return true;
  }
  if (element.type === "text" && element.autocomplete === "username") {
    return true;
  }
  const form = element.closest("form");
  if (form?.querySelector('input[type="password"]')) {
    return true;
  }
  return false;
}
export function isNearViewportBottom(element) {
  const rect = element.getBoundingClientRect();
  const visualHeight = window.visualViewport?.height ?? 0;
  const distanceToBottom = visualHeight - rect.bottom;
  return (
    distanceToBottom > -rect.height / 2 && distanceToBottom < rect.height + 32
  );
}
export function isInsidePreventionContainer(element) {
  const scrollContainer = element?.closest(
    '[data-d-scroll~="scroll-container"]'
  );
  return scrollContainer?.matches('[data-d-scroll-focus-prevention="true"]');
}
export function findClosestScrollContainer(element) {
  return element?.closest('[data-d-scroll~="scroll-container"]');
}
