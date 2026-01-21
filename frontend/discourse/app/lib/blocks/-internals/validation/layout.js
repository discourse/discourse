// @ts-check
/**
 * Outlet layout validation utilities.
 *
 * This module provides validation for outlet layouts passed to renderBlocks().
 * It validates block entries, container/children relationships, reserved args,
 * and conditions.
 *
 * Terminology:
 * - **Block Entry**: An object in a layout that specifies how to use a block.
 * - **Outlet Layout**: An array of block entries defining which blocks appear in an outlet.
 *
 * @module discourse/lib/blocks/-internals/validation/layout
 */

import { DEBUG } from "@glimmer/env";
import {
  BlockError,
  raiseBlockError,
} from "discourse/lib/blocks/-internals/error";
import { isBlockPermittedInOutlet } from "discourse/lib/blocks/-internals/matching/outlet-matcher";
import {
  OPTIONAL_MISSING,
  parseBlockReference,
} from "discourse/lib/blocks/-internals/patterns";
import {
  hasBlock,
  isBlockResolved,
  resolveBlock,
} from "discourse/lib/blocks/-internals/registry/block";
import {
  getAllOutlets,
  isValidOutlet,
} from "discourse/lib/blocks/-internals/registry/outlet";
import {
  applyArgDefaults,
  buildErrorPath,
  createValidationContext,
} from "discourse/lib/blocks/-internals/utils";
import { validateArgsAgainstSchema } from "discourse/lib/blocks/-internals/validation/args";
import { validateBlockArgs } from "discourse/lib/blocks/-internals/validation/block-args";
import {
  runCustomValidation,
  validateConstraints,
} from "discourse/lib/blocks/-internals/validation/constraints";
import { formatWithSuggestion } from "discourse/lib/string-similarity";

/**
 * Wraps a validation function call with BlockError handling.
 * Catches errors with a `path` property and re-raises with full context.
 *
 * @param {Function} validationFn - The validation function to call.
 * @param {string} errorPrefix - Prefix for the error message.
 * @param {Object} context - Error context including outletName, blockName, path, etc.
 */
function wrapValidationError(validationFn, errorPrefix, context) {
  try {
    validationFn();
  } catch (error) {
    // Errors with path property need context enrichment
    if (error.path) {
      raiseBlockError(`${errorPrefix}: ${error.message}`, {
        ...context,
        errorPath: buildErrorPath(context.path, error.path),
      });
    }
    throw error;
  }
}

/**
 * Validates that a block is permitted in the specified outlet.
 * Checks allowedOutlets and deniedOutlets metadata if present.
 *
 * @param {Object} metadata - Block metadata with outlet restrictions.
 * @param {string} outletName - The outlet being validated.
 * @param {string} blockName - The block name for error messages.
 * @param {Object} context - Error context for raiseBlockError.
 * @returns {boolean} True if validation passed, false if error was raised.
 */
function validateOutletPermission(metadata, outletName, blockName, context) {
  if (!metadata?.allowedOutlets && !metadata?.deniedOutlets) {
    return true;
  }

  const permission = isBlockPermittedInOutlet(
    outletName,
    metadata.allowedOutlets,
    metadata.deniedOutlets
  );

  if (!permission.permitted) {
    raiseBlockError(
      `Block "${blockName}" at ${context.path} cannot be rendered in outlet "${outletName}": ${permission.reason}.`,
      context
    );
    return false;
  }
  return true;
}

/**
 * Validates container/children relationship.
 * Containers must have children, non-containers cannot have children.
 *
 * @param {Object} entry - The block entry.
 * @param {boolean} isContainer - Whether the block is a container.
 * @param {string} blockName - The block name for error messages.
 * @param {string} outletName - The outlet name for error messages.
 * @param {Object} context - Error context for raiseBlockError.
 * @returns {boolean} True if validation passed, false if error was raised.
 */
function validateContainerChildren(
  entry,
  isContainer,
  blockName,
  outletName,
  context
) {
  const hasChildren = entry.children?.length > 0;

  if (hasChildren && !isContainer) {
    raiseBlockError(
      `Block component ${blockName} in layout ${outletName} cannot have children`,
      context
    );
    return false;
  }

  if (isContainer && !hasChildren) {
    raiseBlockError(
      `Block component ${blockName} in layout ${outletName} must have children`,
      context
    );
    return false;
  }
  return true;
}

/**
 * Validates block constraints and custom validation functions.
 * Applies arg defaults before validation.
 *
 * @param {Object} metadata - Block metadata with constraints/validate.
 * @param {Object} resolvedBlock - The resolved block class.
 * @param {Object} entry - The block entry.
 * @param {string} blockName - The block name for error messages.
 * @param {Object} context - Error context for raiseBlockError.
 */
function validateBlockConstraints(
  metadata,
  resolvedBlock,
  entry,
  blockName,
  context
) {
  if (!metadata?.constraints && !metadata?.validate) {
    return;
  }

  const argsWithDefaults = applyArgDefaults(resolvedBlock, entry.args || {});

  // Validate declarative constraints
  if (metadata.constraints) {
    const constraintError = validateConstraints(
      metadata.constraints,
      argsWithDefaults,
      blockName
    );
    if (constraintError) {
      raiseBlockError(
        `Invalid block "${blockName}" at ${context.path} for outlet "${context.outletName}": ${constraintError}`,
        { ...context, errorPath: "constraints" }
      );
    }
  }

  // Run custom validation function
  if (metadata.validate) {
    const customErrors = runCustomValidation(
      metadata.validate,
      argsWithDefaults
    );
    if (customErrors?.length > 0) {
      const errorMessage =
        customErrors.length === 1
          ? customErrors[0]
          : customErrors.map((e) => `  - ${e}`).join("\n");
      raiseBlockError(
        `Invalid block "${blockName}" at ${context.path} for outlet "${context.outletName}": ${errorMessage}`,
        { ...context, errorPath: "validate" }
      );
    }
  }
}

/**
 * Validates a child block's containerArgs against the parent container's childArgs schema.
 * Reuses the shared validateArgsAgainstSchema function for core validation logic.
 *
 * @param {Object} childEntry - The child block entry.
 * @param {Object} parentChildArgsSchema - The parent's childArgs schema.
 * @param {string} parentName - Parent block name for error messages.
 * @param {Object} context - Error context.
 */
function validateContainerArgs(
  childEntry,
  parentChildArgsSchema,
  parentName,
  context
) {
  const providedArgs = childEntry.containerArgs || {};

  try {
    validateArgsAgainstSchema(
      providedArgs,
      parentChildArgsSchema,
      "containerArgs"
    );
  } catch (error) {
    // Enhance error message with parent context
    const enhancedMessage = error.path?.startsWith("containerArgs.")
      ? `Child block at ${context.path} ${error.message} (required by parent "${parentName}").`
      : `Child block at ${context.path}: ${error.message} (required by parent "${parentName}").`;

    raiseBlockError(enhancedMessage, {
      ...context,
      errorPath: error.path ? `${context.path}.${error.path}` : context.path,
    });
  }
}

/**
 * Validates uniqueness constraints for containerArgs across all sibling children.
 *
 * @param {Array<Object>} childEntries - Array of child block entries.
 * @param {Object} childArgsSchema - The parent's childArgs schema.
 * @param {string} parentName - Parent block name for error messages.
 * @param {string} parentPath - Path to parent for error context.
 * @param {Object} context - Error context.
 */
function validateContainerArgsUniqueness(
  childEntries,
  childArgsSchema,
  parentName,
  parentPath,
  context
) {
  // Find args with unique: true
  const uniqueArgs = Object.entries(childArgsSchema)
    .filter(([, schema]) => schema.unique)
    .map(([name]) => name);

  for (const argName of uniqueArgs) {
    const seenValues = new Map(); // value -> index of first occurrence

    for (let i = 0; i < childEntries.length; i++) {
      const childEntry = childEntries[i];
      const value = childEntry.containerArgs?.[argName];

      // Skip undefined values (uniqueness only applies to provided values)
      if (value === undefined) {
        continue;
      }

      if (seenValues.has(value)) {
        const firstIndex = seenValues.get(value);
        raiseBlockError(
          `Duplicate value "${value}" for containerArgs.${argName} in children of "${parentName}". ` +
            `Found at children[${firstIndex}] and children[${i}]. ` +
            `The "${argName}" arg must be unique among siblings.`,
          {
            ...context,
            path: `${parentPath}.children[${i}]`,
            errorPath: `${parentPath}.children[${i}].containerArgs.${argName}`,
          }
        );
      }

      seenValues.set(value, i);
    }
  }
}

/**
 * Validates that containerArgs is not provided when parent has no childArgs.
 * Follows the pattern: error in dev/test, warn in production.
 *
 * @param {Object} entry - The block entry.
 * @param {Object} parentChildArgsSchema - The parent's childArgs schema (null if none).
 * @param {Object} context - Error context.
 */
function validateOrphanContainerArgs(entry, parentChildArgsSchema, context) {
  if (entry.containerArgs && !parentChildArgsSchema) {
    const message =
      `Block at ${context.path} has "containerArgs" but parent container does not declare "childArgs". ` +
      `Remove the containerArgs or add a childArgs schema to the parent.`;

    if (DEBUG) {
      raiseBlockError(message, context);
    } else {
      // eslint-disable-next-line no-console
      console.warn(`[Blocks] ${message}`);
    }
  }
}

/**
 * Validates block conditions and raises errors with proper context.
 *
 * @param {Object} blocksService - The blocks service with validate method.
 * @param {Object} entry - The block entry containing conditions.
 * @param {string} outletName - The outlet name for error messages.
 * @param {string} blockName - The block name for error messages.
 * @param {string} path - The path in the layout tree for error messages.
 * @param {Error | null} [callSiteError] - Error object capturing where renderBlocks() was called.
 * @param {Array<Object>} [rootLayout] - The root blocks array for error context display.
 */
function validateBlockConditions(
  blocksService,
  entry,
  outletName,
  blockName,
  path,
  callSiteError = null,
  rootLayout = null
) {
  if (!entry.conditions || !blocksService) {
    return;
  }

  try {
    blocksService.validate(entry.conditions);
  } catch (error) {
    // Build context for error message - include rootLayout for tree display
    const context = {
      ...createValidationContext({
        outletName,
        blockName,
        path,
        entry,
        callSiteError,
        rootLayout,
      }),
      conditions: entry.conditions,
    };

    // If error has a path property, build the full errorPath and conditionsPath
    // error.path is relative to conditions (e.g., "params.categoryId")
    if (error.path) {
      context.errorPath = buildErrorPath(
        path,
        buildErrorPath("conditions", error.path)
      );
      // conditionsPath is relative to the conditions object (for formatter)
      context.conditionsPath = error.path;
    }

    raiseBlockError(
      `Invalid conditions for block "${blockName}" in outlet "${outletName}": ${error.message}`,
      context
    );
  }
}

/**
 * Resolves a block reference (string or class) to a BlockClass for validation.
 *
 * This function handles the dual-mode resolution strategy:
 *
 * - **Development/Test mode**: Eagerly resolves all block references including
 *   factory functions. This ensures errors surface early at boot time with clear
 *   stack traces.
 *
 * - **Production mode**: Only resolves if the block is already resolved (not a
 *   pending factory). Factories are left unresolved, with validation deferred to
 *   render time. This enables true lazy loading.
 *
 * **Optional blocks**: Block references ending with `?` are treated as optional.
 * If an optional block is not registered, an object with `OPTIONAL_MISSING`
 * is returned instead of throwing an error. The calling code should check for this
 * marker and skip validation/rendering for the block.
 *
 * @param {string | Object} blockRef - Block name string (possibly with `?` suffix) or BlockClass.
 * @param {string} outletName - Outlet name for error messages.
 * @param {Object} [context] - Context for error messages.
 * @param {string} [context.path] - Path to this entry in the block tree.
 * @param {Object} [context.entry] - The block entry object.
 * @param {Error} [context.callSiteError] - Error capturing call site location.
 * @param {Array} [context.rootLayout] - Root layout array for error display.
 * @returns {Promise<Object | string | { [OPTIONAL_MISSING]: true, name: string }>}
 *   Resolved BlockClass, string name if deferred, or optional missing marker object.
 * @throws {Error} If required block is not registered.
 */
export async function resolveBlockForValidation(
  blockRef,
  outletName,
  context = {}
) {
  // Class reference - return as-is (classes always exist)
  if (typeof blockRef !== "string") {
    return blockRef;
  }

  // Parse optional suffix from block reference
  const { name, optional } = parseBlockReference(blockRef);

  // String reference - check registration
  if (!hasBlock(name)) {
    if (optional) {
      // Optional block not registered - return marker to skip validation
      return { [OPTIONAL_MISSING]: true, name };
    }
    raiseBlockError(
      `Block "${name}" at ${context.path || "unknown"} for outlet "${outletName}" is not registered. ` +
        `Use api.registerBlock() in a pre-initializer before any renderBlocks() configuration.`,
      createValidationContext({
        outletName,
        blockName: name,
        path: context.path,
        entry: context.entry,
        callSiteError: context.callSiteError,
        rootLayout: context.rootLayout,
      })
    );
    return null;
  }

  if (DEBUG) {
    // In dev/test, eagerly resolve to catch factory errors early
    return await resolveBlock(name);
  }

  // In production, only resolve if already resolved (avoid triggering lazy load)
  if (isBlockResolved(name)) {
    return await resolveBlock(name);
  }

  // Return the string name - full validation deferred to render time
  return name;
}

/**
 * Reserved argument names that cannot be used in layout entries.
 * These are used internally by the block system and would conflict with
 * user-provided args. Names starting with underscore are also reserved.
 */
export const RESERVED_ARG_NAMES = Object.freeze([
  "args",
  "block",
  "classNames",
  "containerArgs",
  "outletArgs",
  "outletName",
  "children",
  "conditions",
  "$block$",
  "__visible",
  "__failureReason",
]);

/**
 * Valid top-level keys in block entry objects.
 * Any key not in this list will trigger a validation error, helping catch
 * common typos like `condition` instead of `conditions`.
 */
export const VALID_ENTRY_KEYS = Object.freeze([
  "block", // Block class or name (required)
  "conditions", // Conditions for rendering
  "args", // Arguments to pass to the block
  "containerArgs", // Arguments required by parent container's childArgs schema
  "classNames", // CSS classes to add to wrapper
  "children", // Nested block entries
]);

/**
 * Declarative type validation rules for block entry fields.
 * Each rule specifies how to validate a field's type and generate error messages.
 *
 * @type {Object<string, {
 *   validate: (value: any) => boolean,
 *   expected: string,
 *   actual?: (value: any) => string
 * }>}
 */
const ENTRY_TYPE_RULES = {
  args: {
    validate: (v) => typeof v === "object" && !Array.isArray(v),
    expected: "an object",
    actual: (v) => (Array.isArray(v) ? "array" : typeof v),
  },
  containerArgs: {
    validate: (v) => typeof v === "object" && !Array.isArray(v),
    expected: "an object",
    actual: (v) => (Array.isArray(v) ? "array" : typeof v),
  },
  children: {
    validate: (v) => Array.isArray(v),
    expected: "an array",
    actual: (v) => typeof v,
  },
  classNames: {
    validate: (v) =>
      typeof v === "string" ||
      (Array.isArray(v) && v.every((item) => typeof item === "string")),
    expected: "a string or array of strings",
    actual: (v) =>
      Array.isArray(v) ? "array with non-string items" : typeof v,
  },
  conditions: {
    validate: (v) => typeof v === "object",
    expected: "an object or array",
    actual: (v) => typeof v,
  },
};

/**
 * Validates that a block entry only uses known keys.
 * Uses fuzzy matching to suggest corrections for typos like "condition",
 * "codition", or "conditons" instead of "conditions".
 *
 * Internal keys (starting with `__`) are skipped as they are added by the
 * system during preprocessing (e.g., `__visible`, `__failureReason`).
 *
 * @param {Object} entry - The block entry object.
 * @throws {BlockError} If unknown keys are found.
 */
export function validateEntryKeys(entry) {
  const unknownKeys = Object.keys(entry).filter(
    (key) => !key.startsWith("__") && !VALID_ENTRY_KEYS.includes(key)
  );

  if (unknownKeys.length > 0) {
    // Build helpful suggestions using fuzzy matching from shared lib
    const suggestions = unknownKeys.map((key) =>
      formatWithSuggestion(key, VALID_ENTRY_KEYS)
    );

    const keyWord = unknownKeys.length > 1 ? "keys" : "key";
    // Throw BlockError directly - wrapValidationError will add context
    throw new BlockError(
      `Unknown entry ${keyWord}: ${suggestions.join(", ")}. ` +
        `Valid keys are: ${VALID_ENTRY_KEYS.join(", ")}.`,
      { path: unknownKeys[0] }
    );
  }
}

/**
 * Validates the types of optional entry fields.
 * Iterates over ENTRY_TYPE_RULES to check each field's type.
 *
 * @param {Object} entry - The block entry object.
 * @throws {BlockError} If any field has an invalid type.
 */
export function validateEntryTypes(entry) {
  for (const [field, rule] of Object.entries(ENTRY_TYPE_RULES)) {
    const value = entry[field];
    if (value != null && !rule.validate(value)) {
      const actualType = rule.actual?.(value) ?? typeof value;
      // Throw BlockError directly - wrapValidationError will add context
      throw new BlockError(
        `"${field}" must be ${rule.expected}, got ${actualType}.`,
        { path: field }
      );
    }
  }
}

/**
 * Checks if an argument name is reserved for internal use.
 * Reserved names include explicit names in RESERVED_ARG_NAMES and
 * any name starting with underscore (private by convention).
 *
 * @param {string} argName - The argument name to check
 * @returns {boolean} True if the name is reserved
 */
export function isReservedArgName(argName) {
  return RESERVED_ARG_NAMES.includes(argName) || argName.startsWith("_");
}

/**
 * Validates that block entry args don't use reserved names.
 * Throws an error if any arg name is reserved (either explicitly listed
 * or prefixed with underscore).
 *
 * @param {Object} entry - The block entry
 * @throws {BlockError} If reserved arg names are used
 */
export function validateReservedArgs(entry) {
  if (!entry.args) {
    return;
  }

  const usedReservedArgs = Object.keys(entry.args).filter(isReservedArgName);

  if (usedReservedArgs.length > 0) {
    // Throw BlockError directly - wrapValidationError will add context
    throw new BlockError(
      `Reserved arg names: ${usedReservedArgs.join(", ")}. ` +
        `Names starting with underscore are reserved for internal use.`,
      { path: `args.${usedReservedArgs[0]}` }
    );
  }
}

/**
 * Recursively validates an outlet layout (array of block entries).
 * Validates each block entry and traverses nested children.
 *
 * This function is async to support lazy-loaded blocks:
 * - In dev/test: Eagerly resolves all factories for early error detection.
 * - In production: Defers factory resolution to render time.
 *
 * @param {Array<Object>} layout - The outlet layout (array of block entries) to validate.
 * @param {string} outletName - The outlet these blocks belong to.
 * @param {import("discourse/services/blocks").default} blocksService - Service for validating conditions.
 * @param {Function} isBlockFn - Function to check if component is a block.
 * @param {Function} isContainerBlockFn - Function to check if component is a container block.
 * @param {string} [parentPath=""] - JSON-path style parent location for error context.
 * @param {Error | null} [callSiteError] - Where renderBlocks() was called from.
 * @param {Array<Object>} [rootLayout] - The root layout array for error context display.
 * @param {Object|null} [parentChildArgsSchema=null] - The parent container's childArgs schema, if any.
 * @param {string|null} [parentBlockName=null] - The parent container's block name for error messages.
 * @returns {Promise<void>} Resolves when validation completes.
 * @throws {Error} If any block entry is invalid.
 */
export async function validateLayout(
  layout,
  outletName,
  blocksService,
  isBlockFn,
  isContainerBlockFn,
  parentPath = "",
  callSiteError = null,
  rootLayout = null,
  parentChildArgsSchema = null,
  parentBlockName = null
) {
  // On first call, capture the root layout for error display
  const effectiveRootLayout = rootLayout ?? layout;

  // Validate containerArgs uniqueness across siblings if parent has childArgs with unique constraints
  if (parentChildArgsSchema) {
    validateContainerArgsUniqueness(
      layout,
      parentChildArgsSchema,
      parentBlockName,
      parentPath.replace(/\.children$/, ""),
      createValidationContext({
        outletName,
        path: parentPath,
        callSiteError,
        rootLayout: effectiveRootLayout,
      })
    );
  }

  // Use Promise.all for parallel validation (faster in dev when resolving factories)
  const validationPromises = layout.map(async (entry, index) => {
    const currentPath = `${parentPath}[${index}]`;

    // Validate the block entry itself (whether it has children or not)
    // Returns the block's childArgsSchema if it's a container with childArgs
    const childArgsSchema = await validateEntry(
      entry,
      outletName,
      blocksService,
      isBlockFn,
      isContainerBlockFn,
      currentPath,
      callSiteError,
      effectiveRootLayout,
      parentChildArgsSchema,
      parentBlockName
    );

    // Recursively validate nested children
    if (entry.children) {
      // Get the block name for error messages when passing childArgs to children
      let blockName = null;
      if (childArgsSchema) {
        // We need the block name for error messages - resolve it
        const resolved = await resolveBlockForValidation(
          entry.block,
          outletName,
          createValidationContext({
            outletName,
            path: currentPath,
            entry,
            callSiteError,
            rootLayout: effectiveRootLayout,
          })
        );
        if (
          resolved &&
          typeof resolved !== "string" &&
          !resolved[OPTIONAL_MISSING]
        ) {
          blockName = resolved.blockName;
        }
      }

      await validateLayout(
        entry.children,
        outletName,
        blocksService,
        isBlockFn,
        isContainerBlockFn,
        `${currentPath}.children`,
        callSiteError,
        effectiveRootLayout,
        childArgsSchema,
        blockName
      );
    }
  });

  await Promise.all(validationPromises);
}

/**
 * Validates a single block entry object.
 *
 * Performs comprehensive validation including:
 * - Outlet name is a valid registered outlet (core or custom)
 * - Block reference is valid (string name or @block-decorated class)
 * - Block is registered in the registry
 * - Container/children relationship is valid
 * - No reserved arg names are used
 * - containerArgs match parent's childArgs schema (if applicable)
 * - Conditions are valid (if blocksService is provided)
 *
 * This function is async to support lazy-loaded blocks. In production mode,
 * if a block reference is a string pointing to an unresolved factory, full
 * validation is deferred to render time.
 *
 * @param {Object} entry - The block entry object.
 * @param {typeof import("@glimmer/component").default | string} entry.block - Block class or name string.
 * @param {Object} [entry.args] - Args to pass to the block.
 * @param {Object} [entry.containerArgs] - Args required by parent container's childArgs schema.
 * @param {Array<Object>} [entry.children] - Nested block entries.
 * @param {Array<Object>|Object} [entry.conditions] - Conditions for rendering.
 * @param {string} outletName - The outlet this block belongs to.
 * @param {import("discourse/services/blocks").default} blocksService - Service for validating conditions.
 * @param {Function} isBlockFn - Function to check if component is a block.
 * @param {Function} isContainerBlockFn - Function to check if component is a container block.
 * @param {string} [path] - JSON-path style location in layout (e.g., "[3].children[0]").
 * @param {Error | null} [callSiteError] - Where renderBlocks() was called from.
 * @param {Array<Object>} [rootLayout] - The root layout array for error context display.
 * @param {Object|null} [parentChildArgsSchema=null] - The parent container's childArgs schema, if any.
 * @param {string|null} [parentBlockName=null] - The parent container's block name for error messages.
 * @returns {Promise<Object|null>} The block's childArgsSchema if it's a container with childArgs, otherwise null.
 * @throws {Error} If validation fails.
 */
export async function validateEntry(
  entry,
  outletName,
  blocksService,
  isBlockFn,
  isContainerBlockFn,
  path,
  callSiteError = null,
  rootLayout = null,
  parentChildArgsSchema = null,
  parentBlockName = null
) {
  // Create context without blockName for early validation errors
  const earlyContext = createValidationContext({
    outletName,
    path,
    entry,
    callSiteError,
    rootLayout,
  });

  if (!isValidOutlet(outletName)) {
    const allOutlets = getAllOutlets();
    const suggestion = formatWithSuggestion(outletName, allOutlets);
    raiseBlockError(
      `Unknown block outlet: ${suggestion}. ` +
        `Register custom outlets with api.registerBlockOutlet() in a pre-initializer. ` +
        `Available outlets: ${allOutlets.join(", ")}`,
      earlyContext
    );
    return null;
  }

  // Validate entry structure (keys and types) with error tracing
  wrapValidationError(
    () => {
      validateEntryKeys(entry);
      validateEntryTypes(entry);
    },
    `Invalid block entry at ${path} for outlet "${outletName}"`,
    earlyContext
  );

  if (!entry.block) {
    raiseBlockError(
      `Block entry at ${path} for outlet "${outletName}" is missing required "block" property.`,
      earlyContext
    );
    return null;
  }

  // Resolve block reference (string name or class)
  // In dev: eagerly resolves factories
  // In prod: returns string if factory is unresolved (defers to render time)
  const resolvedBlock = await resolveBlockForValidation(
    entry.block,
    outletName,
    earlyContext
  );

  // If resolution returned null (error was raised), exit early
  if (resolvedBlock === null) {
    return null;
  }

  // Optional block not registered - skip validation entirely
  if (resolvedBlock?.[OPTIONAL_MISSING]) {
    return null;
  }

  // In production with unresolved factory, defer full validation to render time
  // We've already verified the block name is registered in resolveBlockForValidation
  if (typeof resolvedBlock === "string") {
    const blockName = resolvedBlock;

    // Still validate conditions since they don't depend on the block class
    validateBlockConditions(
      blocksService,
      entry,
      outletName,
      blockName,
      path,
      callSiteError,
      rootLayout
    );

    // Skip class-specific validation (will happen at render time)
    return null;
  }

  // Full validation with resolved class
  if (!isBlockFn(resolvedBlock)) {
    raiseBlockError(
      `Block "${resolvedBlock?.blockName}" at ${path} for outlet "${outletName}" is not a valid @block-decorated component.`,
      earlyContext
    );
    return null;
  }

  const blockName = resolvedBlock.blockName;
  const metadata = resolvedBlock.blockMetadata;

  // Build base context for all validation errors in this block
  const baseContext = createValidationContext({
    outletName,
    blockName,
    path,
    entry,
    callSiteError,
    rootLayout,
  });

  // Validate outlet permission (allowedOutlets/deniedOutlets)
  if (!validateOutletPermission(metadata, outletName, blockName, baseContext)) {
    return null;
  }

  // Validate container/children relationship
  const isContainer = isContainerBlockFn(resolvedBlock);
  if (
    !validateContainerChildren(
      entry,
      isContainer,
      blockName,
      outletName,
      baseContext
    )
  ) {
    return null;
  }

  // Validate reserved args and block args against schema
  const errorPrefix = `Invalid block "${blockName}" at ${path} for outlet "${outletName}"`;
  wrapValidationError(
    () => validateReservedArgs(entry),
    errorPrefix,
    baseContext
  );
  wrapValidationError(
    () => validateBlockArgs(entry, resolvedBlock),
    errorPrefix,
    baseContext
  );

  // Validate constraints and custom validation (after applying defaults)
  validateBlockConstraints(
    metadata,
    resolvedBlock,
    entry,
    blockName,
    baseContext
  );

  // Validate conditions if service is available
  validateBlockConditions(
    blocksService,
    entry,
    outletName,
    blockName,
    path,
    callSiteError,
    rootLayout
  );

  // Validate containerArgs against parent's childArgs schema
  if (parentChildArgsSchema) {
    validateContainerArgs(
      entry,
      parentChildArgsSchema,
      parentBlockName,
      baseContext
    );
  }

  // Validate orphan containerArgs (containerArgs without parent's childArgs)
  validateOrphanContainerArgs(entry, parentChildArgsSchema, baseContext);

  // Return the block's childArgsSchema for validating its children
  return isContainer ? metadata.childArgs : null;
}
