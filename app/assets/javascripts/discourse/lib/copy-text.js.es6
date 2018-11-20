/**
 * Copy text to the clipboard. Must be called from within a user gesture (Chrome).
 */
export default function(text, element) {
  let supported = false;
  try {
    // Chrome: This only returns true within a user gesture.
    // Chrome: queryCommandEnabled() only returns true if a selection is
    //   present, so we use queryCommandSupported() instead for the fail-fast.
    if (document.queryCommandSupported("copy")) {
      supported = true;
    }
  } catch (e) {
    // Ignore
  }
  if (!supported) {
    return;
  }

  let newRange = document.createRange();
  newRange.selectNode(element);
  const selection = window.getSelection();
  selection.removeAllRanges();
  selection.addRange(newRange);

  try {
    if (document.execCommand("copy")) {
      return true;
    }
  } catch (e) {
    // Ignore
  }
  return false;
}
