// @ts-check
/**
 * Block error handling and entry formatting utilities.
 *
 * This module provides error classes, formatting utilities for error display,
 * and helpers for human-readable console output during block validation.
 *
 * @module discourse/lib/blocks/core/error
 */
import { DEBUG } from "@glimmer/env";

/* Entry Formatter Utilities */

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
 * Renders a block entry object with the error path highlighted.
 * Shows the structure with proper indentation and adds a comment marker
 * to indicate where the error occurred.
 *
 * @param {Object|Array} entry - The block entry object to render.
 * @param {string} errorPath - The path to the error (e.g., "conditions.any[0][0].querParams").
 * @param {Object} [options] - Formatting options.
 * @param {string} [options.prefix] - Optional prefix to skip in the path (e.g., "conditions").
 * @param {string} [options.label] - Label to show before the entry (e.g., "conditions:").
 * @returns {string} Formatted string with the error location highlighted.
 */
export function formatEntryWithErrorPath(entry, errorPath, options = {}) {
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
   * Recursively renders the entry object with highlighting.
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

    // Object - filter out private keys (starting with _)
    const keys = Object.keys(obj).filter((k) => !k.startsWith("_"));

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

  const rendered = render(entry, 0, []);
  return label ? `${label} ${rendered}` : rendered;
}

/**
 * Truncates an object for display in error messages.
 * Handles special cases like block classes, children arrays, and circular references.
 *
 * @param {*} obj - The object to truncate.
 * @param {number} [maxDepth=2] - Maximum nesting depth before truncating.
 * @param {number} [maxKeys=5] - Maximum number of keys to show per object.
 * @param {WeakSet} [_seen=null] - Internal parameter for tracking circular references.
 * @returns {*} Truncated representation of the object.
 */
export function truncateForDisplay(
  obj,
  maxDepth = 2,
  maxKeys = 5,
  _seen = null
) {
  if (obj === null || typeof obj !== "object") {
    return obj;
  }

  // Initialize seen set on first call to track circular references
  const seen = _seen ?? new WeakSet();

  // Handle circular references
  if (seen.has(obj)) {
    return "[Circular]";
  }
  seen.add(obj);

  if (maxDepth <= 0) {
    return Array.isArray(obj) ? "[...]" : "{...}";
  }

  if (Array.isArray(obj)) {
    if (obj.length > maxKeys) {
      return [
        ...obj
          .slice(0, maxKeys)
          .map((v) => truncateForDisplay(v, maxDepth - 1, maxKeys, seen)),
        "...",
      ];
    }
    return obj.map((v) => truncateForDisplay(v, maxDepth - 1, maxKeys, seen));
  }

  // Filter out private keys (starting with _)
  const keys = Object.keys(obj).filter((k) => !k.startsWith("_"));
  const result = {};
  const displayKeys = keys.slice(0, maxKeys);

  for (const key of displayKeys) {
    // Handle special keys that don't serialize well or are verbose
    if (key === "block") {
      result[key] = `<${obj[key]?.blockName || "Component"}>`;
    } else if (key === "children") {
      result[key] = `[${obj[key]?.length || 0} children]`;
    } else {
      result[key] = truncateForDisplay(obj[key], maxDepth - 1, maxKeys, seen);
    }
  }

  if (keys.length > maxKeys) {
    result["..."] = `(${keys.length - maxKeys} more)`;
  }

  return result;
}

/* Error Handling */

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
  // @ts-ignore - V8-specific API
  if (Error.captureStackTrace) {
    // @ts-ignore - V8-specific API
    Error.captureStackTrace(error, callerFn);
  }

  return error;
}

/**
 * Builds a tree-style breadcrumb showing the path from root to error.
 * Uses Unicode box-drawing characters for visual hierarchy.
 *
 * @param {Array|Object} rootLayout - The root layout (usually an array of block entries).
 * @param {string} errorPath - The path to the error (e.g., "[4].children[2].args.nme").
 * @returns {string} Tree-style breadcrumb string.
 *
 * @example
 * // Returns:
 * // └─ [4] BlockGroup (name: "callouts")
 * //    └─ children[2] BlockGroup
 * //       └─ args.nme  ← error here
 */
function buildBreadcrumb(rootLayout, errorPath) {
  const segments = parseConditionPath(errorPath);
  const lines = [];
  let current = rootLayout;
  let indent = "";

  for (let i = 0; i < segments.length; i++) {
    const seg = segments[i];

    if (typeof seg === "number" && Array.isArray(current)) {
      // Array index - show block info
      const block = current[seg];
      const blockClass = block?.block;
      const blockName = blockClass?.blockName || blockClass?.name || "Block";
      const nameArg = block?.args?.name ? ` (name: "${block.args.name}")` : "";
      lines.push(`${indent}└─ [${seg}] ${blockName}${nameArg}`);
      current = block;
      indent += "   ";
    } else if (
      typeof seg === "string" &&
      current &&
      typeof current === "object"
    ) {
      // Object key - check if this is a terminal segment or intermediate
      const isLastSegment = i === segments.length - 1;
      const nextSeg = segments[i + 1];
      const value = current[seg];

      if (seg === "children" && typeof nextSeg === "number") {
        // "children" followed by index - continue traversal
        current = value;
      } else if (isLastSegment) {
        // Final segment - this is the error location
        lines.push(`${indent}└─ ${seg}  ← error here`);
      } else if (seg === "args" || seg === "conditions") {
        // Show remaining path as the error location
        const remaining = segments.slice(i).join(".");
        lines.push(`${indent}└─ ${remaining}  ← error here`);
        break;
      } else {
        current = value;
      }
    }
  }

  return lines.join("\n");
}

/**
 * Formats the error context into a human-readable string for console output.
 *
 * When an `errorPath` is provided, uses the path-aware formatter to show
 * the error location within the entry with a comment marker.
 *
 * @param {Object} context - The error context.
 * @returns {string} Formatted context string, or empty string if no context.
 */
function formatErrorContext(context) {
  if (!context) {
    return "";
  }

  const parts = [];

  // Use errorPath if available, otherwise fall back to path
  // Many validation calls use "path" for block location in the tree
  const effectivePath = context.errorPath || context.path;

  // Display the error path location - use tree-style breadcrumb when rootLayout is available
  if (effectivePath) {
    if (context.rootLayout) {
      try {
        const breadcrumb = buildBreadcrumb(context.rootLayout, effectivePath);
        parts.push(`Location:\n${breadcrumb}`);
      } catch {
        // Fallback to plain path if breadcrumb fails
        parts.push(`Location: ${effectivePath}`);
      }
    } else {
      parts.push(`Location: ${effectivePath}`);
    }
  }

  // Priority: rootLayout tree > conditions > individual entry
  // Always prefer showing the full tree when rootLayout is available
  if (context.rootLayout && effectivePath) {
    // Root layout available - show full nesting path from root to error
    try {
      const layoutStr = formatEntryWithErrorPath(
        context.rootLayout,
        effectivePath
      );
      parts.push(`\nContext:\n${layoutStr}`);
    } catch {
      parts.push("Context: [unable to format]");
    }
  } else if (context.conditions && context.conditionsPath) {
    // Fallback: conditions with path-aware formatter
    // conditionsPath is relative to conditions object (e.g., "params.categoryId")
    try {
      const conditionsStr = formatEntryWithErrorPath(
        context.conditions,
        context.conditionsPath,
        { label: "conditions:" }
      );
      parts.push(`\nContext:\n${conditionsStr}`);
    } catch {
      parts.push("Context: [unable to format]");
    }
  } else if (context.entry && effectivePath) {
    // Fallback: individual block entry - strip path prefix for relative path
    try {
      let relativePath = effectivePath;
      if (context.path && effectivePath.startsWith(context.path)) {
        relativePath = effectivePath.slice(context.path.length);
        if (relativePath.startsWith(".")) {
          relativePath = relativePath.slice(1);
        }
      }
      const entryStr = formatEntryWithErrorPath(context.entry, relativePath);
      parts.push(`\nContext:\n${entryStr}`);
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
      parts.push(`Conditions:\n${conditionsStr}`);
    } catch {
      parts.push("Conditions: [unable to serialize]");
    }
  } else if (context.entry) {
    try {
      const entryStr = JSON.stringify(
        truncateForDisplay(context.entry),
        null,
        2
      );
      parts.push(`Block entry:\n${entryStr}`);
    } catch {
      parts.push("Block entry: [unable to serialize]");
    }
  }

  return parts.length > 0 ? `\n\n${parts.join("\n")}` : "";
}

/**
 * Error thrown when block validation fails.
 * Used by block entry and condition validation to report
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
   * @param {string} [options.path] - Path to the error within the layout
   *   (e.g., "[0].conditions.any[0].type" or "[0].args.showIcon").
   */
  constructor(message, options) {
    super(message, options);
    this.name = "BlockError";
    this.path = options?.path;
  }
}

/**
 * Raises a block error by throwing a `BlockError`.
 *
 * If context is provided, the error message will include the block
 * entry for debugging.
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
 * @param {string} [context.path] - Path within the layout to the error (e.g., "[2].conditions.params.categoryId").
 *   Used by validation code to indicate where errors occurred. Combined with `errorPath` for display.
 * @param {Object} [context.entry] - The block entry being validated.
 * @param {Object} [context.conditions] - The conditions being validated.
 * @param {string} [context.errorPath] - Full path to the error for display (e.g., "[2].conditions.params.categoryId").
 * @param {Array<Object>} [context.rootLayout] - The root outlet layout for tree display in errors.
 * @param {Error | null} [context.callSiteError] - Error object capturing where renderBlocks() was called.
 * @throws {BlockError} Always throws.
 */
export function raiseBlockError(message, context = null) {
  // Warn in DEBUG mode when entry-related errors are missing rootLayout
  // This helps catch future validation code that forgets to pass rootLayout
  if (DEBUG) {
    const hasPath = context?.path || context?.errorPath;
    const isEntryError =
      context?.entry || context?.conditions || context?.outletName;

    if (hasPath && isEntryError && !context?.rootLayout) {
      // eslint-disable-next-line no-console
      console.warn(
        `[Blocks] raiseBlockError called with path but no rootLayout. ` +
          `Add rootLayout to context for better error display. ` +
          `Path: ${context?.path || context?.errorPath}`
      );
    }
  }

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
    // @ts-ignore - Adding path property to Error for BlockError compatibility
    error.path = context.path;
  } else {
    error = new BlockError(fullMessage, { path: context?.path });
  }

  throw error;
}
