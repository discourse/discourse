import { DEBUG } from "@glimmer/env";

/**
 * Captures the current call site as an Error object, excluding internal frames.
 * Call this at the entry point (e.g., renderBlocks) to capture where
 * the user's code called into the block system.
 *
 * Uses `Error.captureStackTrace` (V8-specific) to exclude the calling function
 * and everything above it from the stack trace. This means the stack will
 * point directly to the user's code, not to internal block system functions.
 *
 * @param {Function} callerFn - The function to exclude from the stack trace.
 *   Pass the function that calls `captureCallSite` (e.g., `renderBlocks`).
 * @returns {Error} An Error object with stack trace starting from callerFn's caller.
 */
export function captureCallSite(callerFn) {
  const error = new Error();

  // V8-specific: exclude callerFn and everything above from the stack trace.
  // In non-V8 browsers, this is a no-op and the full stack is preserved.
  if (Error.captureStackTrace) {
    Error.captureStackTrace(error, callerFn);
  }

  return error;
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
function formatConfigWithErrorPath(config, errorPath, options = {}) {
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
      const conditionsStr = formatConfigWithErrorPath(
        context.conditions,
        context.errorPath,
        { prefix: "conditions", label: "conditions:" }
      );
      parts.push(`\nContext:\n${conditionsStr}`);
    } catch {
      parts.push("Context: [unable to format]");
    }
  } else if (context.config && context.errorPath) {
    // Block config with error path - use path-aware formatter
    try {
      const configStr = formatConfigWithErrorPath(
        context.config,
        context.errorPath
      );
      parts.push(`\nContext:\n${configStr}`);
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
 * Supports the `cause` option to chain errors together. When a `cause` is
 * provided (typically the call site Error from `captureCallSite()`), browsers
 * will display both stack traces together, allowing developers to see both
 * where the error occurred and where the block was registered.
 *
 * @class BlockError
 * @extends Error
 */
export class BlockError extends Error {
  /**
   * Creates a new BlockError.
   *
   * @param {string} message - The error message.
   * @param {Object} [options] - Error options.
   * @param {Error} [options.cause] - The underlying cause of this error.
   */
  constructor(message, options) {
    super(message, options);
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
 * If context is provided, the error message will include the block
 * configuration for debugging.
 *
 * If a `callSiteError` is present in the context, it is reused with the
 * new message. This preserves the original stack trace pointing to where
 * `renderBlocks()` was called, which is more useful than pointing to this
 * function. Source maps are applied automatically by the browser.
 *
 * @param {string} message - The error message.
 * @param {Object} [context] - Optional error context for better error messages.
 * @param {string} [context.outletName] - The outlet name where the block is registered.
 * @param {string} [context.blockName] - The name of the block being validated.
 * @param {string} [context.path] - JSON-path style location in config (e.g., "blocks[3].children[0]").
 * @param {Object} [context.config] - The full block config being validated.
 * @param {Object} [context.conditions] - The conditions config being validated.
 * @param {string} [context.errorPath] - Path within the config to the error (e.g., "conditions.any[0].type").
 * @param {Error | null} [context.callSiteError] - Error object capturing where renderBlocks() was called.
 * @throws {BlockError} In DEBUG mode.
 */
export function raiseBlockError(message, context = null) {
  // Append context info to the message if available
  const contextInfo = formatErrorContext(context);
  const fullMessage = `[Blocks] ${message}${contextInfo}`;

  let error;

  // If we have a call site error, reuse it with updated message.
  // This preserves the stack trace pointing to where renderBlocks() was called,
  // which is more useful than pointing to raiseBlockError().
  if (context?.callSiteError) {
    error = context.callSiteError;
    error.name = "BlockError";
    error.message = fullMessage;
  } else {
    error = new BlockError(fullMessage);
  }

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
