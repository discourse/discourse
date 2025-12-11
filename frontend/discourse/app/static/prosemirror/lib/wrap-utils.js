/**
 * Parse an attributes string into flat object (matches server behavior)
 * @param {string} attrsString - The attributes string to parse
 * @returns {Object} Flat object like {wrap: "toc", id: "123"}
 */
export function parseAttributesString(attrsString) {
  if (!attrsString.trim()) {
    return {};
  }

  const attrs = {};
  const parts = attrsString.trim().split(/\s+/);

  for (const part of parts) {
    if (part.startsWith("=")) {
      attrs.wrap = part.slice(1);
    } else if (part.includes("=")) {
      const [key, ...valueParts] = part.split("=");
      attrs[key] = valueParts.join("=");
    }
  }

  return attrs;
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

  let result = "";

  // Handle wrap name first
  if (data.wrap) {
    result = `=${data.wrap}`;
  }

  // Handle other attributes
  const otherAttrs = Object.entries(data)
    .filter(([key]) => key !== "wrap")
    .map(([key, value]) => `${key}=${value}`)
    .join(" ");

  if (otherAttrs) {
    if (result) {
      result += ` ${otherAttrs}`;
    } else {
      result = ` ${otherAttrs}`;
    }
  }

  return result;
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
