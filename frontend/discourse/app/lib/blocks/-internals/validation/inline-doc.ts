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
 * @param value - The value to check.
 * @returns Whether the value is a valid inline-rich-text doc.
 */
export function isInlineDoc(value: unknown): boolean {
  if (!value || typeof value !== "object") {
    return false;
  }
  const doc = value as { type?: unknown; content?: unknown };
  if (doc.type !== "doc") {
    return false;
  }
  if (!Array.isArray(doc.content)) {
    return false;
  }
  return doc.content.every(isInlineNode);
}

function isInlineNode(node: unknown): boolean {
  if (!node || typeof node !== "object") {
    return false;
  }
  const n = node as { type?: unknown; text?: unknown; marks?: unknown };
  if (n.type === "hard_break") {
    // Hard breaks carry no other state.
    return Object.keys(n).every((k) => k === "type");
  }
  if (n.type !== "text") {
    return false;
  }
  if (typeof n.text !== "string") {
    return false;
  }
  if (n.marks === undefined) {
    return true;
  }
  if (!Array.isArray(n.marks)) {
    return false;
  }
  return n.marks.every(isInlineMark);
}

function isInlineMark(mark: unknown): boolean {
  if (!mark || typeof mark !== "object") {
    return false;
  }
  const m = mark as { type?: unknown; attrs?: unknown };
  if (!ALLOWED_MARKS.has(m.type as string)) {
    return false;
  }
  if (m.type === "link") {
    if (!m.attrs || typeof m.attrs !== "object") {
      return false;
    }
    return isSafeHref((m.attrs as { href?: unknown }).href);
  }
  return true;
}
