const NON_CARET_INPUT_TYPES = new Set([
  "button",
  "checkbox",
  "file",
  "image",
  "reset",
  "submit",
]);

/**
 * Whether the target owns a text caret and should keep the native context menu.
 *
 * @param {EventTarget | null} target - The contextmenu event's target.
 * @returns {boolean}
 */
export default function isContextMenuExemptTarget(target) {
  if (!(target instanceof HTMLElement)) {
    return false;
  }
  const tag = target.tagName;
  if (tag === "TEXTAREA" || target.isContentEditable) {
    return true;
  }
  return tag === "INPUT" && !NON_CARET_INPUT_TYPES.has(target.type);
}
