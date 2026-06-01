// @ts-check
import { isSafeHref } from "discourse/lib/safe-href";

const ALLOWED_MARKS = new Set(["strong", "em", "link"]);

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
