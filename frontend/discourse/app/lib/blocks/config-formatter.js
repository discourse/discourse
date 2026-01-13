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
   * Renders a truncated (shallow) representation of a value.
   * Used for keys/items not on the error path to provide context without deep nesting.
   *
   * @param {*} obj - The value to render.
   * @returns {string} Truncated string representation.
   */
  function renderTruncated(obj) {
    if (obj === undefined) {
      return "undefined";
    }
    if (obj === null) {
      return "null";
    }
    // Handle functions/classes (including block components) before primitive check
    if (typeof obj === "function") {
      return `<${obj.blockName || obj.name || "Function"}>`;
    }
    if (typeof obj !== "object") {
      return JSON.stringify(obj);
    }
    // Handle block component references on objects with blockName
    if (obj.blockName) {
      return `<${obj.blockName}>`;
    }
    if (Array.isArray(obj)) {
      return obj.length === 0 ? "[]" : `[ ${obj.length} items ]`;
    }
    const keys = Object.keys(obj);
    return keys.length === 0 ? "{}" : "{ ... }";
  }

  /**
   * Renders the remaining path segments for a missing key.
   * Returns an array of lines to be joined.
   *
   * @param {Array<string|number>} segments - Remaining path segments.
   * @param {number} depth - Current indentation depth.
   * @returns {Array<string>} Array of formatted lines.
   */
  function renderMissingPath(segments, depth) {
    const indent = "  ".repeat(depth);
    const lines = [];

    if (segments.length === 0) {
      return lines;
    }

    const [seg, ...rest] = segments;

    if (rest.length === 0) {
      // Final segment - show as missing with error marker
      lines.push(`${indent}  ${seg}: <missing>, // <-- error here`);
    } else {
      // Intermediate segment - open nested object
      lines.push(`${indent}  ${seg}: { // <-- missing`);
      lines.push(...renderMissingPath(rest, depth + 1));
      lines.push(`${indent}  },`);
    }

    return lines;
  }

  /**
   * Recursively renders the config object with highlighting.
   * Shows all keys at each level, but truncates values not on the error path.
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

    // Values past the error location get truncated representation
    if (isPastErrorLocation) {
      return renderTruncated(obj);
    }

    if (obj === undefined) {
      return "undefined";
    }

    if (obj === null) {
      return "null";
    }

    // Handle functions/classes (including block components) before primitive check
    if (typeof obj === "function") {
      return `<${obj.blockName || obj.name || "Function"}>`;
    }

    if (typeof obj !== "object") {
      return JSON.stringify(obj);
    }

    // Handle block component references on objects with blockName
    if (obj.blockName) {
      return `<${obj.blockName}>`;
    }

    if (Array.isArray(obj)) {
      if (obj.length === 0) {
        return "[]";
      }

      // Find which item (if any) is on the error path
      let itemOnPathIndex = -1;
      for (let i = 0; i < obj.length; i++) {
        const itemPath = [...currentPath, i];
        const isItemOnPath = itemPath.every(
          (seg, j) => j >= errorSegments.length || seg === errorSegments[j]
        );
        if (isItemOnPath) {
          itemOnPathIndex = i;
          break;
        }
      }

      const lines = ["["];

      // Show "..." for items before the one on path
      if (itemOnPathIndex > 0) {
        lines.push(`${indent}  ...`);
      }

      // Show the item on path (or all items if none is on path)
      if (itemOnPathIndex >= 0) {
        const itemPath = [...currentPath, itemOnPathIndex];
        const value = render(obj[itemOnPathIndex], depth + 1, itemPath);
        const comma = itemOnPathIndex < obj.length - 1 ? "," : "";

        // Check if this array item is the exact error location
        const isItemTheError =
          itemPath.length === errorSegments.length &&
          itemPath.every((seg, j) => seg === errorSegments[j]);
        const errorMarker = isItemTheError ? " // <-- error here" : "";

        lines.push(`${indent}  ${value}${comma}${errorMarker}`);

        // Show "..." for items after the one on path
        if (itemOnPathIndex < obj.length - 1) {
          lines.push(`${indent}  ...`);
        }
      } else {
        // No item on path - show all truncated
        for (let i = 0; i < obj.length; i++) {
          const value = renderTruncated(obj[i]);
          const comma = i < obj.length - 1 ? "," : "";
          lines.push(`${indent}  ${value}${comma}`);
        }
      }

      lines.push(`${indent}]`);
      return lines.join("\n");
    }

    // Object
    const keys = Object.keys(obj);

    // Check if we need to render a synthetic entry for a missing key on the error path.
    // This handles both:
    // 1. Final missing key (e.g., "nme" typo when "name" exists)
    // 2. Intermediate missing key (e.g., "args" missing entirely when error is "args.name")
    const nextErrorSegment = errorSegments[currentPath.length];
    const needsSyntheticEntry =
      isOnErrorPath &&
      typeof nextErrorSegment === "string" &&
      !keys.includes(nextErrorSegment);

    if (keys.length === 0 && !needsSyntheticEntry) {
      return "{}";
    }

    const lines = ["{"];

    // Render all keys to provide context, but truncate values not on the error path
    for (const key of keys) {
      const keyPath = [...currentPath, key];
      const isKeyOnPath = keyPath.every(
        (seg, j) => j >= errorSegments.length || seg === errorSegments[j]
      );
      const isKeyTheError =
        isOnErrorPath &&
        currentPath.length === errorSegments.length - 1 &&
        key === errorKey;

      // Use full rendering for keys on path, truncated for others
      const value =
        isKeyOnPath || isKeyTheError
          ? render(obj[key], depth + 1, keyPath)
          : renderTruncated(obj[key]);
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
    }

    // Handle missing keys on the error path - render synthetic entry showing the path
    // This covers both intermediate missing keys (e.g., "args" when error is "args.name")
    // and final missing keys (e.g., typo "nme" when "name" exists)
    if (needsSyntheticEntry) {
      const remainingPath = errorSegments.slice(currentPath.length);
      const isAtFinalKey = remainingPath.length === 1;

      if (isAtFinalKey) {
        // Final key is missing - show as missing
        lines.push(
          `${indent}  ${nextErrorSegment}: <missing>, // <-- error here`
        );
      } else {
        // Intermediate key is missing - show the path through it
        // Put the missing comment on the opening brace line
        lines.push(`${indent}  ${nextErrorSegment}: { // <-- missing`);
        lines.push(...renderMissingPath(remainingPath.slice(1), depth + 1));
        lines.push(`${indent}  },`);
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
