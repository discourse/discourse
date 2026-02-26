// @ts-check
/**
 * Block error handling and entry formatting utilities.
 *
 * This module provides error classes, formatting utilities for error display,
 * and helpers for human-readable console output during block validation.
 *
 * @module discourse/lib/blocks/-internals/error
 */
import { DEBUG } from "@glimmer/env";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";

/* Value Display Helpers */

/**
 * Formats a simple value (primitive, function, or block reference) for display.
 * Returns null if the value is a complex type (array/object) that needs special handling.
 *
 * @param {*} obj - The value to format.
 * @returns {string|null} String representation, or null if complex type.
 */
function formatSimpleValue(obj) {
  if (obj === undefined) {
    return "undefined";
  }
  if (obj === null) {
    return "null";
  }
  if (typeof obj === "function") {
    const blockName = getBlockMetadata(obj)?.blockName;
    return `<${blockName || obj.name || "Function"}>`;
  }
  if (typeof obj !== "object") {
    return JSON.stringify(obj);
  }
  const blockName = getBlockMetadata(obj)?.blockName;
  if (blockName) {
    return `<${blockName}>`;
  }
  return null;
}

/**
 * Formats a value as a truncated string for console display.
 * Returns shallow representations like "{ ... }" or "[ 3 items ]".
 *
 * Note: This returns STRINGS for console output. For JSON-serializable
 * truncation, use truncateForDisplay() instead.
 *
 * @param {*} obj - The value to format.
 * @returns {string} Truncated string representation.
 */
function formatTruncatedValue(obj) {
  const simple = formatSimpleValue(obj);
  if (simple !== null) {
    return simple;
  }

  if (Array.isArray(obj)) {
    return obj.length === 0 ? "[]" : `[ ${obj.length} items ]`;
  }

  const keys = Object.keys(obj);
  return keys.length === 0 ? "{}" : "{ ... }";
}

/* Path Parsing */

/**
 * Parses a condition path string into path segments.
 * Handles both dot notation (`.key`) and bracket notation (`[0]`).
 *
 * @param {string} path - The path string (e.g., "conditions.any[0][1].queryParams").
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

/* Path-Aware Entry Rendering */

/**
 * Renders block entries with error path highlighting.
 * Displays the structure with proper indentation and marks where errors occurred.
 */
class PathHighlightRenderer {
  /** @type {Array<string|number>} */
  #errorSegments;

  /** @type {string|number} */
  #errorKey;

  /** @type {string|undefined} */
  #label;

  /**
   * @param {string} errorPath - Path to the error (e.g., "conditions.any[0].type").
   * @param {Object} [options] - Formatting options.
   * @param {string} [options.prefix] - Prefix to skip in the path.
   * @param {string} [options.label] - Label to show before the entry.
   */
  constructor(errorPath, options = {}) {
    const { prefix, label } = options;
    const pathSegments = parseConditionPath(errorPath);

    const startIndex = prefix && pathSegments[0] === prefix ? 1 : 0;
    this.#errorSegments = pathSegments.slice(startIndex);
    this.#errorKey = this.#errorSegments.at(-1);
    this.#label = label;
  }

  /**
   * Renders the entry with the error path highlighted.
   *
   * @param {Object|Array} entry - The block entry object to render.
   * @returns {string} Formatted string with error location highlighted.
   */
  render(entry) {
    const rendered = this.#renderValue(entry, 0, []);
    return this.#label ? `${this.#label} ${rendered}` : rendered;
  }

  /**
   * Checks if the current path is on the error path.
   *
   * @param {Array<string|number>} currentPath - Current path segments.
   * @returns {boolean} True if on error path.
   */
  #isOnErrorPath(currentPath) {
    return currentPath.every(
      (seg, i) =>
        i >= this.#errorSegments.length || seg === this.#errorSegments[i]
    );
  }

  /**
   * Checks if we've passed the error location in the tree.
   *
   * @param {Array<string|number>} currentPath - Current path segments.
   * @returns {boolean} True if past error location.
   */
  #isPastErrorLocation(currentPath) {
    return currentPath.length > this.#errorSegments.length;
  }

  /**
   * Renders any value, dispatching to the appropriate handler.
   *
   * @param {*} obj - The value to render.
   * @param {number} depth - Current indentation depth.
   * @param {Array<string|number>} currentPath - Path segments to current location.
   * @returns {string} Rendered string.
   */
  #renderValue(obj, depth, currentPath) {
    if (this.#isPastErrorLocation(currentPath)) {
      return formatTruncatedValue(obj);
    }

    const simple = formatSimpleValue(obj);
    if (simple !== null) {
      return simple;
    }

    if (Array.isArray(obj)) {
      return this.#renderArray(obj, depth, currentPath);
    }

    return this.#renderObject(obj, depth, currentPath);
  }

  /**
   * Renders an array with path highlighting.
   *
   * @param {Array} arr - The array to render.
   * @param {number} depth - Current indentation depth.
   * @param {Array<string|number>} currentPath - Path segments to current location.
   * @returns {string} Rendered string.
   */
  #renderArray(arr, depth, currentPath) {
    if (arr.length === 0) {
      return "[]";
    }

    const indent = "  ".repeat(depth);
    const itemOnPathIndex = this.#findItemOnPath(arr, currentPath);
    const lines = ["["];

    if (itemOnPathIndex >= 0) {
      this.#renderArrayWithHighlightedItem(
        arr,
        itemOnPathIndex,
        depth,
        currentPath,
        indent,
        lines
      );
    } else {
      this.#renderArrayAllTruncated(arr, indent, lines);
    }

    lines.push(`${indent}]`);
    return lines.join("\n");
  }

  /**
   * Finds which array item (if any) is on the error path.
   *
   * @param {Array} arr - The array to search.
   * @param {Array<string|number>} currentPath - Current path segments.
   * @returns {number} Index of item on path, or -1 if none.
   */
  #findItemOnPath(arr, currentPath) {
    for (let i = 0; i < arr.length; i++) {
      const itemPath = [...currentPath, i];
      if (this.#isOnErrorPath(itemPath)) {
        return i;
      }
    }
    return -1;
  }

  /**
   * Renders an array with a highlighted item on the error path.
   *
   * @param {Array} arr - The array to render.
   * @param {number} itemIndex - Index of the highlighted item.
   * @param {number} depth - Current indentation depth.
   * @param {Array<string|number>} currentPath - Current path segments.
   * @param {string} indent - Current indentation string.
   * @param {Array<string>} lines - Output lines array.
   */
  #renderArrayWithHighlightedItem(
    arr,
    itemIndex,
    depth,
    currentPath,
    indent,
    lines
  ) {
    if (itemIndex > 0) {
      lines.push(`${indent}  ...`);
    }

    const itemPath = [...currentPath, itemIndex];
    const value = this.#renderValue(arr[itemIndex], depth + 1, itemPath);
    const comma = itemIndex < arr.length - 1 ? "," : "";
    const errorMarker = this.#isExactErrorLocation(itemPath)
      ? " // <-- error here"
      : "";

    lines.push(`${indent}  ${value}${comma}${errorMarker}`);

    if (itemIndex < arr.length - 1) {
      lines.push(`${indent}  ...`);
    }
  }

  /**
   * Renders all array items as truncated values.
   *
   * @param {Array} arr - The array to render.
   * @param {string} indent - Current indentation string.
   * @param {Array<string>} lines - Output lines array.
   */
  #renderArrayAllTruncated(arr, indent, lines) {
    for (let i = 0; i < arr.length; i++) {
      const value = formatTruncatedValue(arr[i]);
      const comma = i < arr.length - 1 ? "," : "";
      lines.push(`${indent}  ${value}${comma}`);
    }
  }

  /**
   * Checks if a path is the exact error location.
   *
   * @param {Array<string|number>} path - Path to check.
   * @returns {boolean} True if this is the exact error location.
   */
  #isExactErrorLocation(path) {
    return (
      path.length === this.#errorSegments.length &&
      path.every((seg, j) => seg === this.#errorSegments[j])
    );
  }

  /**
   * Renders an object with path highlighting.
   *
   * @param {Object} obj - The object to render.
   * @param {number} depth - Current indentation depth.
   * @param {Array<string|number>} currentPath - Path segments to current location.
   * @returns {string} Rendered string.
   */
  #renderObject(obj, depth, currentPath) {
    const indent = "  ".repeat(depth);
    const keys = Object.keys(obj).filter((k) => !k.startsWith("_"));
    const isOnPath = this.#isOnErrorPath(currentPath);
    const nextErrorSegment = this.#errorSegments[currentPath.length];
    const needsSyntheticEntry =
      isOnPath &&
      typeof nextErrorSegment === "string" &&
      !keys.includes(nextErrorSegment);

    if (keys.length === 0 && !needsSyntheticEntry) {
      return "{}";
    }

    const lines = ["{"];
    this.#renderObjectKeys(
      obj,
      keys,
      depth,
      currentPath,
      isOnPath,
      indent,
      lines
    );

    if (needsSyntheticEntry) {
      this.#renderSyntheticEntry(currentPath, indent, lines);
    }

    lines.push(`${indent}}`);
    return lines.join("\n");
  }

  /**
   * Renders all keys of an object.
   *
   * @param {Object} obj - The object being rendered.
   * @param {Array<string>} keys - Keys to render.
   * @param {number} depth - Current indentation depth.
   * @param {Array<string|number>} currentPath - Current path segments.
   * @param {boolean} isOnPath - Whether current location is on error path.
   * @param {string} indent - Current indentation string.
   * @param {Array<string>} lines - Output lines array.
   */
  #renderObjectKeys(obj, keys, depth, currentPath, isOnPath, indent, lines) {
    for (const key of keys) {
      const keyPath = [...currentPath, key];
      const isKeyOnPath = this.#isOnErrorPath(keyPath);
      const isKeyTheError =
        isOnPath &&
        currentPath.length === this.#errorSegments.length - 1 &&
        key === this.#errorKey;

      const value =
        isKeyOnPath || isKeyTheError
          ? this.#renderValue(obj[key], depth + 1, keyPath)
          : formatTruncatedValue(obj[key]);
      const errorMarker = isKeyTheError ? " // <-- error here" : "";

      this.#appendKeyValueLine(key, value, errorMarker, indent, lines);
    }
  }

  /**
   * Appends a key-value line to the output, handling multiline values.
   *
   * @param {string} key - The object key.
   * @param {string} value - The rendered value.
   * @param {string} errorMarker - Error marker string (or empty).
   * @param {string} indent - Current indentation string.
   * @param {Array<string>} lines - Output lines array.
   */
  #appendKeyValueLine(key, value, errorMarker, indent, lines) {
    if (value.includes("\n")) {
      const [firstLine, ...restLines] = value.split("\n");
      lines.push(`${indent}  ${key}: ${firstLine}${errorMarker}`);
      lines.push(`${restLines.join("\n")},`);
    } else {
      lines.push(`${indent}  ${key}: ${value},${errorMarker}`);
    }
  }

  /**
   * Renders a synthetic entry for missing keys on the error path.
   *
   * @param {Array<string|number>} currentPath - Current path segments.
   * @param {string} indent - Current indentation string.
   * @param {Array<string>} lines - Output lines array.
   */
  #renderSyntheticEntry(currentPath, indent, lines) {
    const remainingPath = this.#errorSegments.slice(currentPath.length);
    const nextSegment = remainingPath[0];
    const isAtFinalKey = remainingPath.length === 1;

    if (isAtFinalKey) {
      lines.push(`${indent}  ${nextSegment}: <missing>, // <-- error here`);
    } else {
      lines.push(`${indent}  ${nextSegment}: { // <-- missing`);
      lines.push(
        ...this.#renderMissingPath(
          remainingPath.slice(1),
          currentPath.length + 1
        )
      );
      lines.push(`${indent}  },`);
    }
  }

  /**
   * Renders the remaining path segments for a missing key.
   *
   * @param {Array<string|number>} segments - Remaining path segments.
   * @param {number} depth - Current indentation depth.
   * @returns {Array<string>} Array of formatted lines.
   */
  #renderMissingPath(segments, depth) {
    const indent = "  ".repeat(depth);
    const lines = [];

    if (segments.length === 0) {
      return lines;
    }

    const [seg, ...rest] = segments;

    if (rest.length === 0) {
      lines.push(`${indent}  ${seg}: <missing>, // <-- error here`);
    } else {
      lines.push(`${indent}  ${seg}: { // <-- missing`);
      lines.push(...this.#renderMissingPath(rest, depth + 1));
      lines.push(`${indent}  },`);
    }

    return lines;
  }
}

/**
 * Renders a block entry object with the error path highlighted.
 * Shows the structure with proper indentation and adds a comment marker
 * to indicate where the error occurred.
 *
 * @param {Object|Array} entry - The block entry object to render.
 * @param {string} errorPath - The path to the error (e.g., "conditions.any[0][0].queryParams").
 * @param {Object} [options] - Formatting options.
 * @param {string} [options.prefix] - Optional prefix to skip in the path (e.g., "conditions").
 * @param {string} [options.label] - Label to show before the entry (e.g., "conditions:").
 * @returns {string} Formatted string with the error location highlighted.
 */
export function formatEntryWithErrorPath(entry, errorPath, options = {}) {
  return new PathHighlightRenderer(errorPath, options).render(entry);
}

/**
 * Truncates an object for JSON serialization in error messages.
 * Returns actual objects/arrays with truncated content, not strings.
 *
 * Note: This returns OBJECTS for JSON.stringify(). For string representations
 * in console output, use formatTruncatedValue() instead.
 *
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
      result[key] = `<${getBlockMetadata(obj[key])?.blockName || "Component"}>`;
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
 *   Pass the function that calls `captureCallSite` (e.g., `_renderBlocks`).
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
 * //    └─ [2] ChildBlockName
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
      const blockName =
        getBlockMetadata(blockClass)?.blockName || blockClass?.name || "Block";
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
 * Supports the standard `cause` option from ES2022 to chain errors together.
 * Note: `raiseBlockError()` uses a different approach - it reuses the
 * `callSiteError` directly (mutating its message and name) rather than
 * passing it as `cause`. This preserves the original stack trace pointing
 * to where `renderBlocks()` was called.
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
