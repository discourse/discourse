// quotes only group when they open a value, so apostrophes inside words don't
const SEGMENT_PATTERN = /(?:(?<=^|[\s:,+])"[^"]*"|(?<=^|[\s:,+])'[^']*'|\S)+/g;
const PREFIX_PATTERN = /^(?:-=|=-|-|=)/;

/**
 * @typedef {object} FilterQueryToken
 * @property {string} raw - the segment exactly as it appears in the query
 * @property {string} prefix - modifier such as `-` or `=` ("" when absent)
 * @property {string | null} filterName - e.g. "category"; null for free text
 * @property {string | null} value - text after the colon; null for free text
 */

/**
 * Splits a filter query into whitespace-separated segments, keeping quoted
 * values together.
 *
 * @param {string} text
 * @returns {string[]}
 */
export function splitFilterQuery(text) {
  return (text || "").match(SEGMENT_PATTERN) || [];
}

/**
 * @param {string} raw
 * @returns {FilterQueryToken}
 */
export function parseFilterToken(raw) {
  const prefix = raw.match(PREFIX_PATTERN)?.[0] || "";
  const withoutPrefix = raw.substring(prefix.length);
  const colonIndex = withoutPrefix.indexOf(":");

  if (colonIndex <= 0) {
    return { raw, prefix: "", filterName: null, value: null };
  }

  return {
    raw,
    prefix,
    filterName: withoutPrefix.substring(0, colonIndex),
    value: withoutPrefix.substring(colonIndex + 1),
  };
}

/**
 * Whether a segment is complete enough to become a token, i.e. not a bare
 * filter name or a value ending in a delimiter.
 *
 * @param {string} raw
 * @returns {boolean}
 */
export function isCompleteSegment(raw) {
  const { filterName, value } = parseFilterToken(raw);
  return !!raw && (!filterName || !/(^|[,+])$/.test(value));
}

/**
 * Separates the segments the user has finished typing (followed by
 * whitespace) from the one still being typed. An unbalanced quote keeps
 * everything from that quote onwards in the draft.
 *
 * @param {string} text
 * @returns {{ committed: string[], draft: string }}
 */
export function splitCommittedSegments(text) {
  text ??= "";

  const lastWhitespace = text.search(/\s\S*$/);
  if (lastWhitespace === -1 || hasUnbalancedQuote(text)) {
    return { committed: [], draft: text.trimStart() };
  }

  return {
    committed: splitFilterQuery(text.substring(0, lastWhitespace)),
    draft: text.substring(lastWhitespace + 1),
  };
}

function hasUnbalancedQuote(text) {
  const stripped = text.replace(/"[^"]*"|'[^']*'/g, "");
  // only quotes that open a value count; apostrophes inside words don't
  return /(^|[\s:,+])["']/.test(stripped);
}
