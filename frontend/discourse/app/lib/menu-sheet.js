/**
 * With the mobile tab bar showing, the header's menus become sheets rather
 * than sliding in from the side: the forum's menu rises from the bottom, by
 * the tab bar, and the user menu drops from the top, by its avatar. Keyed on
 * the same classes as their styles, so the two can't disagree.
 *
 * @param {HTMLElement} panel A header menu panel.
 * @returns {"bottom"|"top"|null} The edge the panel's sheet comes from, or
 * null when it slides in from the side.
 */
export function menuSheetEdge(panel) {
  if (!document.documentElement.classList.contains("mobile-tab-bar-visible")) {
    return null;
  }

  if (panel.closest(".hamburger-panel")) {
    return "bottom";
  }

  if (panel.closest(".user-menu")) {
    return "top";
  }

  return null;
}

/**
 * A percentage, so the sheet stays fully hidden while its deferred content
 * renders and grows it.
 *
 * @param {"bottom"|"top"} edge
 * @returns {string} The transform that hides a sheet past its edge.
 */
export function menuSheetClosedTransform(edge) {
  return `translate3d(0, ${edge === "top" ? -100 : 100}%, 0)`;
}
