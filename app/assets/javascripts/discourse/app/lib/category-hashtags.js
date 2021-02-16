export const SEPARATOR = ":";
import {
  caretPosition,
  caretRowCol,
  inCodeBlock,
} from "discourse/lib/utilities";

export function replaceSpan($elem, categorySlug, categoryLink, type) {
  type = type ? ` data-type="${type}"` : "";
  $elem.replaceWith(
    `<a href="${categoryLink}" class="hashtag"${type}>#<span>${categorySlug}</span></a>`
  );
}

export function categoryHashtagTriggerRule(textarea, opts) {
  const result = caretRowCol(textarea);
  const row = result.rowNum;
  let col = result.colNum;
  let line = textarea.value.split("\n")[row - 1];

  if (opts && opts.backSpace) {
    col = col - 1;
    line = line.slice(0, line.length - 1);

    // Don't trigger autocomplete when backspacing into a `#category |` => `#category|`
    if (/^#{1}\w+/.test(line)) {
      return false;
    }
  }

  // Don't trigger autocomplete when ATX-style headers are used
  if (col < 6 && line.slice(0, col) === "#".repeat(col)) {
    return false;
  }

  if (inCodeBlock(textarea.value, caretPosition(textarea))) {
    return false;
  }

  return true;
}
