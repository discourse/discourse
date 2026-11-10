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
 * Intentionally separate from the predicate that decides which elements own the arrow keys:
 * that one counts `select` as editable, which is the wrong answer to this question.
 *
 * @param target - The contextmenu event's target.
 */
export default function isContextMenuExemptTarget(
  target: EventTarget | null
): boolean {
  if (!(target instanceof HTMLElement)) {
    return false;
  }

  const tag = target.tagName;

  if (tag === "TEXTAREA" || target.isContentEditable) {
    return true;
  }

  return (
    tag === "INPUT" &&
    !NON_CARET_INPUT_TYPES.has((target as HTMLInputElement).type)
  );
}
