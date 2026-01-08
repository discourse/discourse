/**
 * Config formatting utilities for error display and debugging.
 *
 * These utilities help format block configurations for human-readable
 * display in error messages, console output, and debug tools.
 *
 * @module discourse/lib/blocks/config-formatter
 */

/**
 * Parses a condition path string into path segments.
 * Handles both dot notation (`.key`) and bracket notation (`[0]`).
 *
 * @param {string} path - The path string (e.g., "conditions.any[0][1].querParams").
 * @returns {Array<string|number>} Array of path segments.
 *
 * @example
 * parseConditionPath("conditions.any[0][1].type")
 * // Returns: ["conditions", "any", 0, 1, "type"]
 */
export function parseConditionPath(path) {
  const segments = [];
  let current = "";

  for (let i = 0; i < path.length; i++) {
    const char = path[i];

    if (char === ".") {
      if (current) {
        segments.push(current);
        current = "";
      }
    } else if (char === "[") {
      if (current) {
        segments.push(current);
        current = "";
      }
      // Find closing bracket
      let j = i + 1;
      while (j < path.length && path[j] !== "]") {
        j++;
      }
      const index = path.slice(i + 1, j);
      segments.push(parseInt(index, 10));
      i = j; // Skip to after the closing bracket
    } else {
      current += char;
    }
  }

  if (current) {
    segments.push(current);
  }

  return segments;
}

/**
 * Renders a config object with the error path highlighted.
 * Shows the structure with proper indentation and adds a comment marker
 * to indicate where the error occurred.
 *
 * @param {Object|Array} config - The config object to render.
 * @param {string} errorPath - The path to the error (e.g., "conditions.any[0][0].querParams").
 * @param {Object} [options] - Formatting options.
 * @param {string} [options.prefix] - Optional prefix to skip in the path (e.g., "conditions").
 * @param {string} [options.label] - Label to show before the config (e.g., "conditions:").
 * @returns {string} Formatted string with the error location highlighted.
 */
export function formatConfigWithErrorPath(config, errorPath, options = {}) {
  const { prefix, label } = options;
  const pathSegments = parseConditionPath(errorPath);

  // Skip prefix if present (it's implicit in the label)
  const startIndex = prefix && pathSegments[0] === prefix ? 1 : 0;
  const errorSegments = pathSegments.slice(startIndex);
  const errorKey = errorSegments[errorSegments.length - 1];

  /**
   * Recursively renders the config object with highlighting.
   *
   * @param {*} obj - The object to render.
   * @param {number} depth - Current indentation depth.
   * @param {Array<string|number>} currentPath - Path segments to current location.
   * @returns {string} Rendered string.
   */
  function render(obj, depth, currentPath) {
    const indent = "  ".repeat(depth);
    const isOnErrorPath = currentPath.every(
      (seg, i) => i >= errorSegments.length || seg === errorSegments[i]
    );
    const isPastErrorLocation = currentPath.length > errorSegments.length;

    // Truncate values past the error location
    if (isPastErrorLocation) {
      if (obj === null) {
        return "null";
      }
      if (typeof obj !== "object") {
        return JSON.stringify(obj);
      }
      return Array.isArray(obj) ? "[ ... ]" : "{ ... }";
    }

    if (obj === null) {
      return "null";
    }

    if (typeof obj !== "object") {
      return JSON.stringify(obj);
    }

    // Handle block component references specially
    if (obj.blockName || (typeof obj === "function" && obj.name)) {
      return `<${obj.blockName || obj.name || "Component"}>`;
    }

    if (Array.isArray(obj)) {
      if (obj.length === 0) {
        return "[]";
      }

      const lines = ["["];
      for (let i = 0; i < obj.length; i++) {
        const itemPath = [...currentPath, i];
        const isItemOnPath = itemPath.every(
          (seg, j) => j >= errorSegments.length || seg === errorSegments[j]
        );

        if (isItemOnPath || currentPath.length < errorSegments.length) {
          const value = render(obj[i], depth + 1, itemPath);
          const comma = i < obj.length - 1 ? "," : "";
          lines.push(`${indent}  ${value}${comma}`);
        } else if (i === 0) {
          // Show ellipsis for items not on path
          lines.push(`${indent}  ...`);
        }
      }
      lines.push(`${indent}]`);
      return lines.join("\n");
    }

    // Object
    const keys = Object.keys(obj);
    if (keys.length === 0) {
      return "{}";
    }

    const lines = ["{"];
    let shownEllipsis = false;

    for (const key of keys) {
      const keyPath = [...currentPath, key];
      const isKeyOnPath = keyPath.every(
        (seg, j) => j >= errorSegments.length || seg === errorSegments[j]
      );
      const isKeyTheError =
        isOnErrorPath &&
        currentPath.length === errorSegments.length - 1 &&
        key === errorKey;

      if (isKeyOnPath || isKeyTheError) {
        const value = render(obj[key], depth + 1, keyPath);
        const errorMarker = isKeyTheError ? " // <-- error here" : "";

        // Handle multiline values - put error marker on the key line, not after the value
        if (value.includes("\n")) {
          const firstLine = value.split("\n")[0];
          const restLines = value.split("\n").slice(1).join("\n");
          lines.push(`${indent}  ${key}: ${firstLine}${errorMarker}`);
          lines.push(`${restLines},`);
        } else {
          lines.push(`${indent}  ${key}: ${value},${errorMarker}`);
        }
      } else if (!shownEllipsis) {
        lines.push(`${indent}  ...`);
        shownEllipsis = true;
      }
    }
    lines.push(`${indent}}`);
    return lines.join("\n");
  }

  const rendered = render(config, 0, []);
  return label ? `${label} ${rendered}` : rendered;
}

/**
 * Truncates an object for display in error messages.
 * Handles special cases like block classes and children arrays.
 *
 * @param {*} obj - The object to truncate.
 * @param {number} [maxDepth=2] - Maximum nesting depth before truncating.
 * @param {number} [maxKeys=5] - Maximum number of keys to show per object.
 * @returns {*} Truncated representation of the object.
 */
export function truncateForDisplay(obj, maxDepth = 2, maxKeys = 5) {
  if (obj === null || typeof obj !== "object") {
    return obj;
  }

  if (maxDepth <= 0) {
    return Array.isArray(obj) ? "[...]" : "{...}";
  }

  if (Array.isArray(obj)) {
    if (obj.length > maxKeys) {
      return [
        ...obj
          .slice(0, maxKeys)
          .map((v) => truncateForDisplay(v, maxDepth - 1, maxKeys)),
        "...",
      ];
    }
    return obj.map((v) => truncateForDisplay(v, maxDepth - 1, maxKeys));
  }

  const keys = Object.keys(obj);
  const result = {};
  const displayKeys = keys.slice(0, maxKeys);

  for (const key of displayKeys) {
    // Handle special keys that don't serialize well or are verbose
    if (key === "block") {
      result[key] = `<${obj[key]?.blockName || "Component"}>`;
    } else if (key === "children") {
      result[key] = `[${obj[key]?.length || 0} children]`;
    } else {
      result[key] = truncateForDisplay(obj[key], maxDepth - 1, maxKeys);
    }
  }

  if (keys.length > maxKeys) {
    result["..."] = `(${keys.length - maxKeys} more)`;
  }

  return result;
}
