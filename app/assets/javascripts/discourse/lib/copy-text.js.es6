/**
 * Copy text to the clipboard. Must be called from within a user gesture (Chrome).
 * 复制内容到剪切板（后面英文 user gesture 的部分没看懂，不是没懂字面意思，而是没懂  Chrome 这里是不是限制了什么机制）
 */
export default function(text, element) {
  let supported = false;
  try {
    // Chrome: This only returns true within a user gesture.
    // Chrome: queryCommandEnabled() only returns true if a selection is
    //   present, so we use queryCommandSupported() instead for the fail-fast.
    if (document.queryCommandSupported('copy')) {
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
