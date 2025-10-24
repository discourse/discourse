/**
 * Utility functions for autocomplete result components
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
  try {
    event.preventDefault();
    event.stopPropagation();

    if (typeof onSelectCallback !== "function") {
      return;
    }

    const callbackResult = onSelectCallback(result, index, event);

    if (callbackResult && typeof callbackResult.then === "function") {
      callbackResult.catch((e) => {
        // eslint-disable-next-line no-console
        console.error("[autocomplete] onSelect promise rejected: ", e);
      });
    }
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error("[autocomplete] Click handler error: ", e);
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
