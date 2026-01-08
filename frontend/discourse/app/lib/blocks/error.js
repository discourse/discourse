import { DEBUG } from "@glimmer/env";
import {
  formatConfigWithErrorPath,
  truncateForDisplay,
} from "discourse/lib/blocks/config-formatter";

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
