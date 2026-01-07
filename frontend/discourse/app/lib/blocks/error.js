import { DEBUG } from "@glimmer/env";

/**
 * Current error context, set by the caller before raising errors.
 * Contains block configuration info for better error messages.
 *
 * @type {{ outletName: string, blockName: string, path: string, config: Object, conditions: Object, errorPath: string } | null}
 */
let errorContext = null;

/**
 * Sets the error context for the current validation operation.
 * Call this before validating block configuration to provide context
 * for error messages.
 *
 * @param {Object} context - The error context.
 * @param {string} [context.outletName] - The outlet name where the block is registered.
 * @param {string} [context.blockName] - The name of the block being validated.
 * @param {string} [context.path] - JSON-path style location in config (e.g., "blocks[3].children[0]").
 * @param {Object} [context.config] - The full block config being validated.
 * @param {Object} [context.conditions] - The conditions config being validated.
 * @param {string} [context.errorPath] - Path within the config to the error (e.g., "conditions.any[0].type").
 */
export function setBlockErrorContext(context) {
  errorContext = context;
}

/**
 * Clears the current error context.
 * Call this in a finally block after validation completes.
 */
export function clearBlockErrorContext() {
  errorContext = null;
}

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
function parseConditionPath(path) {
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
 * Renders a conditions config with the error path highlighted.
 * Shows the structure with proper indentation and adds a comment marker
 * to indicate where the error occurred.
 *
 * @param {Object|Array} conditions - The conditions config object.
 * @param {string} errorPath - The path to the error (e.g., "conditions.any[0][0].querParams").
 * @returns {string} Formatted string with the error location highlighted.
 */
function formatConditionsWithErrorPath(conditions, errorPath) {
  const pathSegments = parseConditionPath(errorPath);

  // Skip "conditions" prefix if present (it's implicit)
  const startIndex = pathSegments[0] === "conditions" ? 1 : 0;
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

  return `conditions: ${render(conditions, 0, [])}`;
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
function truncateForDisplay(obj, maxDepth = 2, maxKeys = 5) {
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

/**
 * Formats the error context into a human-readable string for console output.
 *
 * When a `conditionPath` is provided, uses the path-aware formatter to show
 * the error location within the conditions config with a comment marker.
 *
 * @param {Object} context - The error context.
 * @returns {string} Formatted context string, or empty string if no context.
 */
function formatErrorContext(context) {
  if (!context) {
    return "";
  }

  const parts = [];

  // If we have an errorPath, show the full location path
  if (context.errorPath) {
    const fullPath = context.path
      ? `${context.path}.${context.errorPath}`
      : context.errorPath;
    parts.push(`Location: ${fullPath}`);
  }

  // If we have conditions and an errorPath, use the path-aware formatter
  if (context.conditions && context.errorPath) {
    try {
      const conditionsStr = formatConditionsWithErrorPath(
        context.conditions,
        context.errorPath
      );
      parts.push(`\nContext:\n${conditionsStr}`);
    } catch {
      parts.push("Context: [unable to format]");
    }
  } else if (context.conditions) {
    // Fallback to simple display without path highlighting
    try {
      const conditionsStr = JSON.stringify(
        truncateForDisplay(context.conditions),
        null,
        2
      );
      parts.push(`Conditions config:\n${conditionsStr}`);
    } catch {
      parts.push("Conditions config: [unable to serialize]");
    }
  } else if (context.config) {
    try {
      const configStr = JSON.stringify(
        truncateForDisplay(context.config),
        null,
        2
      );
      parts.push(`Block config:\n${configStr}`);
    } catch {
      parts.push("Block config: [unable to serialize]");
    }
  }

  return parts.length > 0 ? `\n\n${parts.join("\n")}` : "";
}

/**
 * Error thrown when block validation fails.
 * Used by block configuration and condition validation to report
 * errors at registration time.
 *
 * @class BlockError
 * @extends Error
 */
export class BlockError extends Error {
  constructor(message) {
    super(message);
    this.name = "BlockError";
  }
}

/**
 * Error thrown during block configuration validation.
 * Includes a path indicating where in the config the error occurred,
 * enabling precise error location display.
 *
 * Used for validation errors in conditions, args, and other nested config
 * structures where path tracking is valuable.
 *
 * @class BlockValidationError
 * @extends Error
 */
export class BlockValidationError extends Error {
  /**
   * Creates a new BlockValidationError.
   *
   * @param {string} message - The error message describing the validation failure.
   * @param {string} path - The path to the error within the config
   *   (e.g., "conditions.any[0][0].querParams" or "args.showIcon").
   */
  constructor(message, path) {
    super(message);
    this.name = "BlockValidationError";
    this.path = path;
  }
}

/**
 * Raises an error in dev/test environments, surfaces to admins in production.
 *
 * In development/test environments, throws a BlockError to fail fast.
 * In production, dispatches a `discourse-error` event that surfaces the error
 * to admin users via a banner (handled by `ClientErrorHandlerService`).
 *
 * If an error context has been set via `setBlockErrorContext()`, the error
 * message will include the block configuration for debugging.
 *
 * @param {string} message - The error message.
 * @throws {BlockError} In DEBUG mode.
 */
export function raiseBlockError(message) {
  // Append context info to the message if available
  const contextInfo = formatErrorContext(errorContext);
  const fullMessage = `[Blocks] ${message}${contextInfo}`;

  const error = new BlockError(fullMessage);

  if (DEBUG) {
    throw error;
  } else {
    // Surface to admins via error banner (only visible to admin users)
    document.dispatchEvent(
      new CustomEvent("discourse-error", {
        detail: {
          messageKey: "broken_block_alert",
          error,
        },
      })
    );
  }
}
