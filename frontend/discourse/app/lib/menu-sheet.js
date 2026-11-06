/**
 * With the mobile tab bar showing, header menus open as sheets: the forum's
 * menu from the bottom and the user menu from the top. Keyed on the classes
 * their styles use, so the two agree.
 *
 * @param {HTMLElement} panel A header menu panel.
 * @returns {"bottom"|"top"|null} The sheet's edge, or null for a side menu.
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
 * A percentage, so the sheet stays hidden while its deferred content grows it.
 *
 * @param {"bottom"|"top"} edge
 * @returns {string}
 */
export function menuSheetClosedTransform(edge) {
  return `translate3d(0, ${edge === "top" ? -100 : 100}%, 0)`;
}
