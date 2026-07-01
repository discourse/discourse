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
