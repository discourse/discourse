/**
 * Maps condition type ids to FontAwesome icon names. Used by the
 * inspector's conditions surface so each rule row carries a visual
 * anchor matching its type — easier to scan than text alone.
 *
 * Unknown types fall back to `circle-question` so the row still
 * renders something rather than collapsing to label-only.
 */
const ICONS: Record<string, string> = {
  user: "user",
  viewport: "mobile-screen-button",
  route: "link",
  setting: "gear",
  "outlet-arg": "code",
};

/**
 * @param typeId - The condition type identifier, when selected.
 * @returns The icon ID for the condition type or the unknown-type fallback.
 */
export function iconForConditionType(
  typeId: string | null | undefined
): string {
  if (!typeId) {
    return "circle-question";
  }
  return ICONS[typeId] ?? "circle-question";
}
