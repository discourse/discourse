export const SEPARATOR = ":";

export function replaceSpan($elem, categorySlug, categoryLink) {
  $elem.replaceWith(`<a href="${categoryLink}" class="hashtag">#<span>${categorySlug}</span></a>`);
};

export function categoryHashtagTriggerRule(textarea, opts) {
  const result = Discourse.Utilities.caretRowCol(textarea);
  const row = result.rowNum;
  var col = result.colNum;
  var line = textarea.value.split("\n")[row - 1];

  if (opts && opts.backSpace) {
    col = col - 1;
    line = line.slice(0, line.length - 1);

    // Don't trigger autocomplete when backspacing into a `#category |` => `#category|`
    if (/^#{1}\w+/.test(line)) return false;
  }

  if (col < 6) {
    // Don't trigger autocomplete when ATX-style headers are used
    return (line.slice(0, col) !== "#".repeat(col));
  } else {
    return true;
  }
}
