/**
 * Shared utilities for list handling across selection quoting, paste normalization,
 * and ProseMirror extensions.
 */

/**
 * Determines if a list is "tight" (compact) based on CommonMark semantics.
 * A tight list has no blank lines between items - its <li> elements do NOT
 * contain block-level <p> elements as direct children.
 *
 * @param {Element} listElement - An <ol> or <ul> element
 * @returns {boolean} True if the list is tight
 */
export function isListTight(listElement) {
  const listItems = listElement.querySelectorAll(":scope > li");
  for (const li of listItems) {
    for (const child of li.children) {
      if (child.tagName === "P") {
        return false;
      }
    }
  }
  return true;
}

/**
 * Sets the data-tight attribute on a list element based on its structure.
 *
 * @param {Element} listElement - An <ol> or <ul> element
 */
export function setTightAttribute(listElement) {
  if (isListTight(listElement)) {
    listElement.setAttribute("data-tight", "true");
  }
}

/**
 * Sets the data-tight attribute on all lists within a container.
 *
 * @param {Element} container - Container element to process
 */
export function setTightAttributeOnAllLists(container) {
  const lists = container.querySelectorAll("ol, ul");
  for (const list of lists) {
    setTightAttribute(list);
  }
}

/**
 * Gets the effective start number for a list item within its parent list.
 * For ordered lists, this accounts for the list's start attribute and
 * the item's position.
 *
 * @param {Element} listElement - The parent <ol> or <ul> element
 * @param {Element|null} listItem - The <li> element (optional)
 * @returns {number} The start number (1 for unordered lists)
 */
export function getListStartNumber(listElement, listItem) {
  if (listElement.tagName !== "OL") {
    return 1;
  }
  const parsed = parseInt(listElement.getAttribute("start") || "1", 10);
  const baseStart = Number.isNaN(parsed) ? 1 : parsed;
  if (!listItem) {
    return baseStart;
  }
  const listItems = listElement.querySelectorAll(":scope > li");
  const itemIndex = Array.from(listItems).indexOf(listItem);
  return baseStart + Math.max(0, itemIndex);
}

/**
 * Creates a list wrapper element with appropriate attributes.
 *
 * @param {string} tagName - "OL" or "UL"
 * @param {number} startNumber - Start number for ordered lists
 * @param {boolean} isTight - Whether the list is tight
 * @returns {HTMLElement} The created list element
 */
export function createListWrapper(tagName, startNumber, isTight) {
  const list = document.createElement(tagName.toLowerCase());
  if (tagName === "OL" && startNumber !== 1) {
    list.setAttribute("start", String(startNumber));
  }
  if (isTight) {
    list.setAttribute("data-tight", "true");
  }
  return list;
}

/**
 * Finds the closest parent list element.
 *
 * @param {Element|null} element - Starting element
 * @returns {Element|null} The closest <ol> or <ul> ancestor
 */
export function findParentList(element) {
  if (element?.tagName === "OL" || element?.tagName === "UL") {
    return element;
  }
  return element?.closest("ol, ul");
}
