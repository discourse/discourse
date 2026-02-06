/**
 * Non-text input types that should not trigger scroll-into-view.
 *
 * @type {Set<string>}
 */
const NON_TEXT_INPUT_TYPES = new Set([
  "checkbox",
  "radio",
  "range",
  "color",
  "file",
  "image",
  "button",
  "submit",
  "reset",
  "hidden",
]);

/**
 * Check if element is a text input that should trigger scroll-into-view.
 * Includes HTMLInputElement (excluding non-text types), HTMLTextAreaElement,
 * and any HTMLElement with contentEditable.
 *
 * @param {HTMLElement} element
 * @returns {boolean}
 */
export default function isTextInput(element) {
  if (!element) {
    return false;
  }

  if (
    element instanceof HTMLInputElement &&
    !NON_TEXT_INPUT_TYPES.has(element.type)
  ) {
    return true;
  }

  if (element instanceof HTMLTextAreaElement) {
    return true;
  }

  if (element instanceof HTMLElement && element.isContentEditable) {
    return true;
  }

  return false;
}
