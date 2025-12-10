/**
 * Utilities for working with wrap tokens and their attributes
 */

/**
 * Parse an attributes string into a structured object
 * @param {string} attrsString - The attributes string to parse (e.g., "=name class=foo data-bar=baz")
 * @returns {Object} Parsed attributes with wrap name and key-value pairs
 */
export function parseAttributesString(attrsString) {
  const attrs = {};
  if (!attrsString.trim()) {
    return attrs;
  }

  // Parse attributes - split by spaces but respect quotes
  const matches = attrsString.match(/(?:(\w+)=)?(?:"([^"]*)"|([^\s]+))/g) || [];

  for (const match of matches) {
    if (match.startsWith("=")) {
      // This is the main wrap value (=name)
      attrs.wrap = match.slice(1);
    } else if (match.includes("=")) {
      const [key, ...valueParts] = match.split("=");
      const value = valueParts.join("=").replace(/^"|"$/g, "");
      if (key === "wrap") {
        attrs.wrap = value;
      } else {
        attrs[key] = value;
      }
    } else {
      // Value without key, treat as wrap value
      attrs.wrap = match;
    }
  }

  return attrs;
}

/**
 * Parse an attributes string into form data structure
 * @param {string} attrsString - The attributes string to parse
 * @returns {Object} Form data with name and attributes array
 */
export function parseAttributesForForm(attrsString) {
  const data = {
    name: "",
    attributes: [],
  };

  if (!attrsString.trim()) {
    return data;
  }

  const parsedAttrs = parseAttributesString(attrsString);

  // Extract the wrap name
  data.name = parsedAttrs.wrap || "";

  // Convert remaining attributes to form structure
  Object.keys(parsedAttrs).forEach((key) => {
    if (key !== "wrap") {
      data.attributes.push({
        key,
        value: parsedAttrs[key],
      });
    }
  });

  return data;
}

/**
 * Serialize form data back to an attributes string
 * @param {string} name - The wrap name
 * @param {Array} attributes - Array of {key, value} objects
 * @returns {string} Serialized attributes string
 */
export function serializeAttributes(name, attributes = []) {
  let attrsString = "";

  if (name?.trim()) {
    attrsString += `=${name.trim()}`;
  }

  if (attributes?.length) {
    const attrParts = attributes
      .filter((attr) => attr.key && attr.value)
      .map((attr) => `${attr.key}=${attr.value}`);

    if (attrParts.length) {
      if (attrsString) {
        attrsString += " ";
      }
      attrsString += attrParts.join(" ");
    }
  }

  return attrsString;
}
