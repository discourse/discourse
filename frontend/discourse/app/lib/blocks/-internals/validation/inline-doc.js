// @ts-check

const ALLOWED_MARKS = new Set(["strong", "em", "link"]);
const ALLOWED_SCHEMES = new Set(["http", "https", "mailto", "tel"]);

/**
 * Structural check for an inline-rich-text ProseMirror doc.
 *
 * A valid inline doc is the canonical PM JSON shape `{ type: "doc", content }`,
 * where every node is either:
 *   - `{ type: "text", text: <string>, marks?: <array> }`
 *   - `{ type: "hard_break" }`
 *
 * Marks are restricted to `strong`, `em`, and `link` (with `attrs.href`
 * validated via {@link isSafeHref}). Anything else is rejected.
 *
 * @param {unknown} value
 * @returns {boolean}
 */
export function isInlineDoc(value) {
  if (!value || typeof value !== "object") {
    return false;
  }
  const doc = /** @type {{ type?: unknown, content?: unknown }} */ (value);
  if (doc.type !== "doc") {
    return false;
  }
  if (!Array.isArray(doc.content)) {
    return false;
  }
  return doc.content.every(isInlineNode);
}

function isInlineNode(node) {
  if (!node || typeof node !== "object") {
    return false;
  }
  if (node.type === "hard_break") {
    // Hard breaks carry no other state.
    return Object.keys(node).every((k) => k === "type");
  }
  if (node.type !== "text") {
    return false;
  }
  if (typeof node.text !== "string") {
    return false;
  }
  if (node.marks === undefined) {
    return true;
  }
  if (!Array.isArray(node.marks)) {
    return false;
  }
  return node.marks.every(isInlineMark);
}

function isInlineMark(mark) {
  if (!mark || typeof mark !== "object") {
    return false;
  }
  if (!ALLOWED_MARKS.has(mark.type)) {
    return false;
  }
  if (mark.type === "link") {
    if (!mark.attrs || typeof mark.attrs !== "object") {
      return false;
    }
    return isSafeHref(mark.attrs.href);
  }
  return true;
}

/**
 * Whether an href is safe to store and render. Rejects dangerous schemes
 * (`javascript:`, `data:`, etc.) and control characters. Permits relative
 * paths, fragment links, and the http/https/mailto/tel schemes.
 *
 * @param {unknown} href
 * @returns {boolean}
 */
export function isSafeHref(href) {
  if (typeof href !== "string" || href.length === 0) {
    return false;
  }

  if (/[\x00-\x1F\x7F]/.test(href)) {
    return false;
  }
  if (href.startsWith("/") || href.startsWith("#") || href.startsWith("?")) {
    return true;
  }
  const match = href.match(/^([a-zA-Z][a-zA-Z0-9+.-]*):/);
  if (!match) {
    return true;
  }
  return ALLOWED_SCHEMES.has(match[1].toLowerCase());
}
