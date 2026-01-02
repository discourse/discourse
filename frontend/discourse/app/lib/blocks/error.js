import { DEBUG } from "@glimmer/env";

/**
 * Current error context, set by the caller before raising errors.
 * Contains block configuration info for better error messages.
 *
 * @type {{ outletName: string, blockName: string, path: string, config: Object, conditions: Object } | null}
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
 * @param {Object} context - The error context.
 * @returns {string} Formatted context string, or empty string if no context.
 */
function formatErrorContext(context) {
  if (!context) {
    return "";
  }

  const parts = [];

  if (context.outletName) {
    parts.push(`Outlet: "${context.outletName}"`);
  }

  if (context.blockName) {
    parts.push(`Block: "${context.blockName}"`);
  }

  if (context.path) {
    parts.push(`Path: ${context.path}`);
  }

  if (context.conditions) {
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
