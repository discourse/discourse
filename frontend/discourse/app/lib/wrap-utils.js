import { buildBBCodeAttrs, serializeBBCodeAttr } from "discourse/lib/text";
import { parseBBCodeTag } from "discourse-markdown-it/features/bbcode-block";

/**
 * Parse an attributes string into flat object (matches server behavior)
 * @param {string} attrsString - The attributes string to parse
 * @returns {Object} Flat object like {wrap: "toc", id: "123"}
 */
export function parseAttributesString(attrsString) {
  if (!attrsString.trim()) {
    return {};
  }

  // Reuse the markdown-it parser so quoting stays in parity with the server
  const source = `[wrap${attrsString}]`;
  const parsed = parseBBCodeTag(source, 0, source.length);

  if (!parsed?.attrs) {
    return {};
  }

  const { _default: wrap, ...rest } = parsed.attrs;
  return wrap ? { wrap, ...rest } : rest;
}

/**
 * Serialize flat object back to BBCode format
 * @param {Object} data - Flat object like {wrap: "toc", id: "123"}
 * @returns {string} Serialized attributes string
 */
export function serializeAttributes(data) {
  if (!data || Object.keys(data).length === 0) {
    return "";
  }

  // An empty name serializes the wrap as the nameless `=value` default
  const wrapName = data.wrap ? serializeBBCodeAttr(data.wrap, "").trim() : "";
  const otherAttrs = buildBBCodeAttrs(data, { skipAttrs: ["wrap"] });

  if (wrapName && otherAttrs) {
    return `${wrapName} ${otherAttrs}`;
  }

  return wrapName || (otherAttrs ? ` ${otherAttrs}` : "");
}

/**
 * Serialize name and attributes array to BBCode format (for modal)
 * @param {string} name - Wrap name
 * @param {Array} attributes - Array of {key, value} objects
 * @returns {string} Serialized attributes string
 */
export function serializeFromForm(name, attributes = []) {
  const data = {};
  if (name) {
    data.wrap = name;
  }
  for (const attr of attributes) {
    if (attr.key && attr.value) {
      data[attr.key] = attr.value;
    }
  }
  return serializeAttributes(data);
}
