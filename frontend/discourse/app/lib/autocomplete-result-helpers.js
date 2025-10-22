/**
 * Utility functions for autocomplete result components
 * Provides reusable behaviors without requiring inheritance
 */

/**
 * Standard handler for autocomplete result click events
 *
 * @param {Function} onSelectCallback - The onSelect callback from args
 * @param {Object} result - The result object that was clicked
 * @param {number} index - Index of the clicked result
 * @param {Event} event - The click event
 */
export function handleAutocompleteResultClick(
  onSelectCallback,
  result,
  index,
  event
) {
  event.preventDefault();
  event.stopPropagation();

  if (typeof onSelectCallback === "function") {
    onSelectCallback(result, index, event);
  }
}

/**
 * Standard handler for calling onRender callback
 *
 * @param {Function} onRenderCallback - The onRender callback from args
 * @param {Array} results - The results array to pass to callback
 */
export function callOnRenderCallback(onRenderCallback, results) {
  if (typeof onRenderCallback === "function") {
    onRenderCallback(results);
  }
}

/**
 * Determine if an item should be selected based on index
 *
 * @param {number} itemIndex - Index of the current item
 * @param {number} selectedIndex - Currently selected index
 * @returns {boolean} Whether this item is selected
 */
export function isItemSelected(itemIndex, selectedIndex) {
  return itemIndex === selectedIndex;
}

/**
 * Find and return the selected item element
 *
 * @param {HTMLElement} container - Container element to search within
 * @param {number} selectedIndex - Index to find
 * @returns {HTMLElement|null} The selected element or null
 */
export function findSelectedItem(container, selectedIndex) {
  if (!container || selectedIndex < 0) {
    return null;
  }

  return container.querySelector(`[data-index="${selectedIndex}"]`);
}
