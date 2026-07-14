// @ts-check

/**
 * Maps condition type ids to FontAwesome icon names. Used by the
 * inspector's conditions surface so each rule row carries a visual
 * anchor matching its type — easier to scan than text alone.
 *
 * Unknown types fall back to `circle-question` so the row still
 * renders something rather than collapsing to label-only.
 */
const ICONS = {
  user: "user",
  viewport: "mobile-screen-button",
  route: "link",
  setting: "gear",
  "outlet-arg": "code",
};

/**
 * @param {string} typeId
 * @returns {string}
 */
export function iconForConditionType(typeId) {
  return ICONS[typeId] ?? "circle-question";
}
