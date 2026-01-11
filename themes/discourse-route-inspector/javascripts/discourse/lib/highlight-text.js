import { htmlSafe } from "@ember/template";

const HIGHLIGHTED_CLASS = `filter-highlighted-text`;
const HTML_START = `<span class="${HIGHLIGHTED_CLASS}">`;
const HTML_END = `</span>`;

/**
 * Highlights occurrences of a query string within a text value
 * @param {string} text - The text to highlight
 * @param {Object|null} filter - Filter object containing query and caseSensitive properties
 * @returns {string|SafeString} - The original text or htmlSafe highlighted text
 */
export function highlightText(text, filter) {
  if (!filter?.query || !text) {
    return text;
  }

  const normalizedText = filter.caseSensitive ? text : text.toLowerCase();
  const normalizedQuery = filter.caseSensitive
    ? filter.query
    : filter.query.toLowerCase();

  let result = "";
  let lastIndex = 0;
  let searchIndex = 0;

  while (searchIndex < normalizedText.length) {
    const index = normalizedText.indexOf(normalizedQuery, searchIndex);
    if (index === -1) {
      result += text.substring(lastIndex);
      break;
    }

    result += text.substring(lastIndex, index);
    result +=
      HTML_START +
      text.substring(index, index + normalizedQuery.length) +
      HTML_END;
    lastIndex = index + normalizedQuery.length;
    searchIndex = lastIndex;
  }

  return htmlSafe(result);
}
