/**
 * Block configuration validation utilities.
 *
 * This module provides validation for block configurations passed to renderBlocks().
 * It validates block components, container/children relationships, reserved args,
 * and conditions.
 *
 * @module discourse/lib/blocks/config-validation
 */

import { DEBUG } from "@glimmer/env";
import { validateBlockArgs } from "discourse/lib/blocks/arg-validation";
import {
  runCustomValidation,
  validateConstraints,
} from "discourse/lib/blocks/constraint-validation";
import { raiseBlockError } from "discourse/lib/blocks/error";
import { isBlockPermittedInOutlet } from "discourse/lib/blocks/outlet-matcher";
import {
  OPTIONAL_MISSING,
  parseBlockReference,
} from "discourse/lib/blocks/patterns";
import {
  getAllOutlets,
  hasBlock,
  isBlockResolved,
  isValidOutlet,
  resolveBlock,
} from "discourse/lib/blocks/registration";
import { applyArgDefaults } from "discourse/lib/blocks/utils";
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
        errorPath: `${context.path}.${error.path}`,
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
 * @param {Object} config - The block configuration.
 * @param {boolean} isContainer - Whether the block is a container.
 * @param {string} blockName - The block name for error messages.
 * @param {string} outletName - The outlet name for error messages.
 * @param {Object} context - Error context for raiseBlockError.
 * @returns {boolean} True if validation passed, false if error was raised.
 */
function validateContainerChildren(
  config,
  isContainer,
  blockName,
  outletName,
  context
) {
  const hasChildren = config.children?.length > 0;
  const displayName = config.name || blockName;

  if (hasChildren && !isContainer) {
    raiseBlockError(
      `Block component ${displayName} in layout ${outletName} cannot have children`,
      context
    );
    return false;
  }

  if (isContainer && !hasChildren) {
    raiseBlockError(
      `Block component ${displayName} in layout ${outletName} must have children`,
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
 * @param {Object} config - The block configuration.
 * @param {string} blockName - The block name for error messages.
 * @param {Object} context - Error context for raiseBlockError.
 */
function validateBlockConstraints(
  metadata,
  resolvedBlock,
  config,
  blockName,
  context
) {
  if (!metadata?.constraints && !metadata?.validate) {
    return;
  }

  const argsWithDefaults = applyArgDefaults(resolvedBlock, config.args || {});

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
 * Validates block conditions and raises errors with proper context.
 *
 * @param {Object} blocksService - The blocks service with validate method.
 * @param {Object} config - The block config containing conditions.
 * @param {string} outletName - The outlet name for error messages.
 * @param {string} blockName - The block name for error messages.
 * @param {string} path - The path in the config tree for error messages.
 * @param {Error | null} [callSiteError] - Error object capturing where renderBlocks() was called.
 */
function validateBlockConditions(
  blocksService,
  config,
  outletName,
  blockName,
  path,
  callSiteError = null
) {
  if (!config.conditions || !blocksService) {
    return;
  }

  try {
    blocksService.validate(config.conditions);
  } catch (error) {
    // Build context for error message
    const context = {
      outletName,
      blockName,
      conditions: config.conditions,
      callSiteError,
    };

    // If error has a path property, build the full errorPath and conditionsPath
    // error.path is relative to conditions (e.g., "params.categoryId")
    if (error.path) {
      context.errorPath = `${path}.conditions.${error.path}`;
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
 * @param {string} [context.path] - Path to this config in the block tree.
 * @param {Object} [context.config] - The block config object.
 * @param {Error} [context.callSiteError] - Error capturing call site location.
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
      { outletName, blockName: name, ...context }
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
 * Reserved argument names that cannot be used in block configurations.
 * These are used internally by the block system and would conflict with
 * user-provided args. Names starting with underscore are also reserved.
 */
export const RESERVED_ARG_NAMES = Object.freeze([
  "classNames",
  "outletArgs",
  "outletName",
  "children",
  "conditions",
  "$block$",
  "__visible",
  "__failureReason",
]);

/**
 * Valid top-level keys in block configuration objects.
 * Any key not in this list will trigger a validation error, helping catch
 * common typos like `condition` instead of `conditions`.
 */
export const VALID_CONFIG_KEYS = Object.freeze([
  "block", // Block class or name (required)
  "args", // Arguments to pass to the block
  "children", // Nested block configurations
  "conditions", // Conditions for rendering
  "name", // Display name for error messages
  "classNames", // CSS classes to add to wrapper
]);

/**
 * Declarative type validation rules for config fields.
 * Each rule specifies how to validate a field's type and generate error messages.
 *
 * @type {Object<string, {
 *   validate: (value: any) => boolean,
 *   expected: string,
 *   actual?: (value: any) => string
 * }>}
 */
const CONFIG_TYPE_RULES = {
  args: {
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
  name: {
    validate: (v) => typeof v === "string",
    expected: "a string",
    actual: (v) => typeof v,
  },
  conditions: {
    validate: (v) => typeof v === "object",
    expected: "an object or array",
    actual: (v) => typeof v,
  },
};

/**
 * Validates that a block config only uses known keys.
 * Uses fuzzy matching to suggest corrections for typos like "condition",
 * "codition", or "conditons" instead of "conditions".
 *
 * Internal keys (starting with `__`) are skipped as they are added by the
 * system during preprocessing (e.g., `__visible`, `__failureReason`).
 *
 * @param {Object} config - The block configuration object.
 * @throws {BlockError} If unknown keys are found.
 */
export function validateConfigKeys(config) {
  const unknownKeys = Object.keys(config).filter(
    (key) => !key.startsWith("__") && !VALID_CONFIG_KEYS.includes(key)
  );

  if (unknownKeys.length > 0) {
    // Build helpful suggestions using fuzzy matching from shared lib
    const suggestions = unknownKeys.map((key) =>
      formatWithSuggestion(key, VALID_CONFIG_KEYS)
    );

    const keyWord = unknownKeys.length > 1 ? "keys" : "key";
    // Use first unknown key for the error path
    raiseBlockError(
      `Unknown config ${keyWord}: ${suggestions.join(", ")}. ` +
        `Valid keys are: ${VALID_CONFIG_KEYS.join(", ")}.`,
      { path: unknownKeys[0] }
    );
  }
}

/**
 * Validates the types of optional config fields.
 * Iterates over CONFIG_TYPE_RULES to check each field's type.
 *
 * @param {Object} config - The block configuration object.
 * @throws {BlockError} If any field has an invalid type.
 */
export function validateConfigTypes(config) {
  for (const [field, rule] of Object.entries(CONFIG_TYPE_RULES)) {
    const value = config[field];
    if (value != null && !rule.validate(value)) {
      const actualType = rule.actual?.(value) ?? typeof value;
      raiseBlockError(
        `"${field}" must be ${rule.expected}, got ${actualType}.`,
        {
          path: field,
        }
      );
    }
  }
}

/**
 * Safely stringifies a block config object for error messages.
 * Handles circular references, limits depth, and truncates output.
 *
 * @param {Object} config - The config object to stringify.
 * @param {number} [maxDepth=2] - Maximum nesting depth to serialize.
 * @param {number} [maxLength=200] - Maximum output string length.
 * @returns {string} A safe string representation of the config.
 */
export function safeStringifyConfig(config, maxDepth = 2, maxLength = 200) {
  const seen = new WeakSet();

  function serialize(value, depth) {
    if (depth > maxDepth) {
      return "[...]";
    }

    if (value === null) {
      return "null";
    }
    if (value === undefined) {
      return "undefined";
    }
    if (typeof value === "string") {
      return `"${value.length > 30 ? value.slice(0, 30) + "..." : value}"`;
    }
    if (typeof value === "number" || typeof value === "boolean") {
      return String(value);
    }
    if (typeof value === "function") {
      return `[Function: ${value.name || "anonymous"}]`;
    }
    if (typeof value === "symbol") {
      return `[Symbol: ${value.description || ""}]`;
    }

    if (typeof value === "object") {
      if (seen.has(value)) {
        return "[Circular]";
      }
      seen.add(value);

      if (Array.isArray(value)) {
        if (value.length === 0) {
          return "[]";
        }
        const items = value.slice(0, 3).map((v) => serialize(v, depth + 1));
        if (value.length > 3) {
          items.push(`... ${value.length - 3} more`);
        }
        return `[${items.join(", ")}]`;
      }

      const keys = Object.keys(value).slice(0, 5);
      if (keys.length === 0) {
        return "{}";
      }
      const pairs = keys.map((k) => `${k}: ${serialize(value[k], depth + 1)}`);
      if (Object.keys(value).length > 5) {
        pairs.push("...");
      }
      return `{${pairs.join(", ")}}`;
    }

    return String(value);
  }

  try {
    const result = serialize(config, 0);
    if (result.length > maxLength) {
      return result.slice(0, maxLength) + "...";
    }
    return result;
  } catch {
    return "[Object]";
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
 * Validates that block config args don't use reserved names.
 * Throws an error if any arg name is reserved (either explicitly listed
 * or prefixed with underscore).
 *
 * @param {Object} config - The block configuration
 * @throws {BlockError} If reserved arg names are used
 */
export function validateReservedArgs(config) {
  if (!config.args) {
    return;
  }

  const usedReservedArgs = Object.keys(config.args).filter(isReservedArgName);

  if (usedReservedArgs.length > 0) {
    raiseBlockError(
      `Reserved arg names: ${usedReservedArgs.join(", ")}. ` +
        `Names starting with underscore are reserved for internal use.`,
      { path: `args.${usedReservedArgs[0]}` }
    );
  }
}

/**
 * Recursively validates an array of block configurations.
 * Validates each block and traverses nested children configurations.
 *
 * This function is async to support lazy-loaded blocks:
 * - In dev/test: Eagerly resolves all factories for early error detection.
 * - In production: Defers factory resolution to render time.
 *
 * @param {Array<Object>} blocksConfig - Block configurations to validate.
 * @param {string} outletName - The outlet these blocks belong to.
 * @param {import("discourse/services/blocks").default} [blocksService] - Service for validating conditions.
 * @param {Function} isBlockFn - Function to check if component is a block.
 * @param {Function} isContainerBlockFn - Function to check if component is a container block.
 * @param {string} [parentPath="blocks"] - JSON-path style parent location for error context.
 * @param {Error | null} [callSiteError] - Where renderBlocks() was called from.
 * @returns {Promise<void>} Resolves when validation completes.
 * @throws {Error} If any block configuration is invalid.
 */
export async function validateConfig(
  blocksConfig,
  outletName,
  blocksService,
  isBlockFn,
  isContainerBlockFn,
  parentPath = "blocks",
  callSiteError = null
) {
  // Use Promise.all for parallel validation (faster in dev when resolving factories)
  const validationPromises = blocksConfig.map(async (blockConfig, index) => {
    const currentPath = `${parentPath}[${index}]`;

    // Validate the block itself (whether it has children or not)
    await validateBlock(
      blockConfig,
      outletName,
      blocksService,
      isBlockFn,
      isContainerBlockFn,
      currentPath,
      callSiteError
    );

    // Recursively validate nested children
    if (blockConfig.children) {
      await validateConfig(
        blockConfig.children,
        outletName,
        blocksService,
        isBlockFn,
        isContainerBlockFn,
        `${currentPath}.children`,
        callSiteError
      );
    }
  });

  await Promise.all(validationPromises);
}

/**
 * Validates a single block configuration object.
 *
 * Performs comprehensive validation including:
 * - Outlet name is a valid registered outlet (core or custom)
 * - Block reference is valid (string name or @block-decorated class)
 * - Block is registered in the registry
 * - Container/children relationship is valid
 * - No reserved arg names are used
 * - Conditions are valid (if blocksService is provided)
 *
 * This function is async to support lazy-loaded blocks. In production mode,
 * if a block reference is a string pointing to an unresolved factory, full
 * validation is deferred to render time.
 *
 * @param {Object} config - The block configuration object.
 * @param {typeof import("@glimmer/component").default | string} config.block - Block class or name string.
 * @param {string} [config.name] - Display name for error messages.
 * @param {Object} [config.args] - Args to pass to the block.
 * @param {Array<Object>} [config.children] - Nested block configurations.
 * @param {Array<Object>|Object} [config.conditions] - Conditions for rendering.
 * @param {string} outletName - The outlet this block belongs to.
 * @param {import("discourse/services/blocks").default} [blocksService] - Service for validating conditions.
 * @param {Function} isBlockFn - Function to check if component is a block.
 * @param {Function} isContainerBlockFn - Function to check if component is a container block.
 * @param {string} [path] - JSON-path style location in config (e.g., "blocks[3].children[0]").
 * @param {Error | null} [callSiteError] - Where renderBlocks() was called from.
 * @returns {Promise<void>} Resolves when validation completes.
 * @throws {Error} If validation fails.
 */
export async function validateBlock(
  config,
  outletName,
  blocksService,
  isBlockFn,
  isContainerBlockFn,
  path,
  callSiteError = null
) {
  if (!isValidOutlet(outletName)) {
    const allOutlets = getAllOutlets();
    const suggestion = formatWithSuggestion(outletName, allOutlets);
    raiseBlockError(
      `Unknown block outlet: ${suggestion}. ` +
        `Register custom outlets with api.registerBlockOutlet() in a pre-initializer. ` +
        `Available outlets: ${allOutlets.join(", ")}`,
      { outletName, path, config, callSiteError }
    );
    return;
  }

  // Validate config structure (keys and types) with error tracing
  wrapValidationError(
    () => {
      validateConfigKeys(config);
      validateConfigTypes(config);
    },
    `Invalid block config at ${path} for outlet "${outletName}"`,
    { outletName, path, config, callSiteError }
  );

  if (!config.block) {
    raiseBlockError(
      `Block config at ${path} for outlet "${outletName}" is missing required "block" property.`,
      { outletName, path, config, callSiteError }
    );
    return;
  }

  // Resolve block reference (string name or class)
  // In dev: eagerly resolves factories
  // In prod: returns string if factory is unresolved (defers to render time)
  const resolvedBlock = await resolveBlockForValidation(
    config.block,
    outletName,
    { path, config, callSiteError }
  );

  // If resolution returned null (error was raised), exit early
  if (resolvedBlock === null) {
    return;
  }

  // Optional block not registered - skip validation entirely
  if (resolvedBlock?.[OPTIONAL_MISSING]) {
    return;
  }

  // In production with unresolved factory, defer full validation to render time
  // We've already verified the block name is registered in resolveBlockForValidation
  if (typeof resolvedBlock === "string") {
    const blockName = resolvedBlock;

    // Still validate conditions since they don't depend on the block class
    validateBlockConditions(
      blocksService,
      config,
      outletName,
      blockName,
      path,
      callSiteError
    );

    // Skip class-specific validation (will happen at render time)
    return;
  }

  // Full validation with resolved class
  if (!isBlockFn(resolvedBlock)) {
    raiseBlockError(
      `Block "${config.name || resolvedBlock?.blockName}" at ${path} for outlet "${outletName}" is not a valid @block-decorated component.`,
      { outletName, path, config, callSiteError }
    );
    return;
  }

  const blockName = resolvedBlock.blockName;
  const metadata = resolvedBlock.blockMetadata;

  // Build base context for all validation errors in this block
  const baseContext = {
    outletName,
    blockName,
    path,
    config,
    callSiteError,
  };

  // Validate outlet permission (allowedOutlets/deniedOutlets)
  if (!validateOutletPermission(metadata, outletName, blockName, baseContext)) {
    return;
  }

  // Validate container/children relationship
  const isContainer = isContainerBlockFn(resolvedBlock);
  if (
    !validateContainerChildren(
      config,
      isContainer,
      blockName,
      outletName,
      baseContext
    )
  ) {
    return;
  }

  // Validate reserved args and block args against schema
  const errorPrefix = `Invalid block "${blockName}" at ${path} for outlet "${outletName}"`;
  wrapValidationError(
    () => validateReservedArgs(config),
    errorPrefix,
    baseContext
  );
  wrapValidationError(
    () => validateBlockArgs(config, resolvedBlock),
    errorPrefix,
    baseContext
  );

  // Validate constraints and custom validation (after applying defaults)
  validateBlockConstraints(
    metadata,
    resolvedBlock,
    config,
    blockName,
    baseContext
  );

  // Validate conditions if service is available
  validateBlockConditions(
    blocksService,
    config,
    outletName,
    blockName,
    path,
    callSiteError
  );
}
