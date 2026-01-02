/**
 * Block configuration validation utilities.
 *
 * This module provides validation for block configurations passed to renderBlocks().
 * It validates block components, container/children relationships, reserved args,
 * and conditions.
 *
 * @module discourse/lib/blocks/config-validation
 */

import { validateBlockArgs } from "discourse/lib/blocks/arg-validation";
import {
  clearBlockErrorContext,
  raiseBlockError,
  setBlockErrorContext,
} from "discourse/lib/blocks/error";
import { BLOCK_OUTLETS } from "discourse/lib/registry/blocks";

/**
 * Reserved argument names that cannot be used in block configurations.
 * These are used internally by the block system and would conflict with
 * user-provided args. Names starting with underscore are also reserved.
 */
export const RESERVED_ARG_NAMES = Object.freeze([
  "classNames",
  "outletName",
  "children",
  "conditions",
  "$block$",
]);

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
 * @param {string} outletName - The outlet name for error messages
 * @throws {Error} If reserved arg names are used
 */
export function validateReservedArgs(config, outletName) {
  if (!config.args) {
    return;
  }

  const usedReservedArgs = Object.keys(config.args).filter(isReservedArgName);

  if (usedReservedArgs.length > 0) {
    raiseBlockError(
      `Block ${config.name} in layout ${outletName} uses reserved arg names: ${usedReservedArgs.join(", ")}. ` +
        `Names starting with underscore are reserved for internal use.`
    );
  }
}

/**
 * Recursively validates an array of block configurations.
 * Validates each block and traverses nested children configurations.
 *
 * @param {Array<Object>} blocksConfig - Block configurations to validate
 * @param {string} outletName - The outlet these blocks belong to
 * @param {import("discourse/services/blocks").default} [blocksService] - Service for validating conditions
 * @param {Function} isBlockFn - Function to check if component is a block
 * @param {Function} isContainerBlockFn - Function to check if component is a container block
 * @param {string} [parentPath="blocks"] - JSON-path style parent location for error context
 * @throws {Error} If any block configuration is invalid
 */
export function validateConfig(
  blocksConfig,
  outletName,
  blocksService,
  isBlockFn,
  isContainerBlockFn,
  parentPath = "blocks"
) {
  blocksConfig.forEach((blockConfig, index) => {
    const currentPath = `${parentPath}[${index}]`;

    // Validate the block itself (whether it has children or not)
    validateBlock(
      blockConfig,
      outletName,
      blocksService,
      isBlockFn,
      isContainerBlockFn,
      currentPath
    );

    // Recursively validate nested children
    if (blockConfig.children) {
      validateConfig(
        blockConfig.children,
        outletName,
        blocksService,
        isBlockFn,
        isContainerBlockFn,
        `${currentPath}.children`
      );
    }
  });
}

/**
 * Validates a single block configuration object.
 * Performs comprehensive validation including:
 * - Outlet name is registered in BLOCK_OUTLETS
 * - Block component exists and is decorated with @block
 * - Container/children relationship is valid
 * - No reserved arg names are used
 * - Conditions are valid (if blocksService is provided)
 *
 * @param {Object} config - The block configuration object
 * @param {typeof import("@glimmer/component").default} config.block - The block component class
 * @param {string} [config.name] - Display name for error messages
 * @param {Object} [config.args] - Args to pass to the block
 * @param {Array<Object>} [config.children] - Nested block configurations
 * @param {Array<Object>|Object} [config.conditions] - Conditions for rendering
 * @param {string} outletName - The outlet this block belongs to
 * @param {import("discourse/services/blocks").default} [blocksService] - Service for validating conditions
 * @param {Function} isBlockFn - Function to check if component is a block
 * @param {Function} isContainerBlockFn - Function to check if component is a container block
 * @param {string} [path] - JSON-path style location in config (e.g., "blocks[3].children[0]")
 * @throws {Error} If validation fails
 */
export function validateBlock(
  config,
  outletName,
  blocksService,
  isBlockFn,
  isContainerBlockFn,
  path
) {
  if (!BLOCK_OUTLETS.includes(outletName)) {
    raiseBlockError(`Unknown block outlet: ${outletName}`);
    return;
  }

  if (!config.block) {
    raiseBlockError(
      `Block in layout for \`${outletName}\` is missing a component: ${safeStringifyConfig(config)}`
    );
    return;
  }

  if (!isBlockFn(config.block)) {
    raiseBlockError(
      `Block component ${config.name} (${config.block}) in layout ${outletName} is not a valid block`
    );
    return;
  }

  // Verify block is registered (security check - prevents use of unregistered blocks)
  // Import lazily to avoid circular dependency at module load time
  const { blockRegistry } = require("discourse/lib/blocks/registration");
  const blockName = config.block.blockName;
  if (!blockRegistry.has(blockName)) {
    raiseBlockError(
      `Block "${blockName}" is not registered. ` +
        `Use api.registerBlock() in a pre-initializer before any renderBlocks() configuration.`
    );
    return;
  }

  // Set error context for all subsequent validation errors
  setBlockErrorContext({
    outletName,
    blockName,
    path,
    config,
  });

  try {
    const hasChildren = config.children?.length > 0;
    const isContainer = isContainerBlockFn(config.block);

    if (hasChildren && !isContainer) {
      raiseBlockError(
        `Block component ${config.name} (${config.block}) in layout ${outletName} cannot have children`
      );
      return;
    }

    if (isContainer && !hasChildren) {
      raiseBlockError(
        `Block component ${config.name} (${config.block}) in layout ${outletName} must have children`
      );
      return;
    }

    validateReservedArgs(config, outletName);

    // Validate block args against metadata schema
    validateBlockArgs(config, outletName);

    // Validate conditions if service is available
    // In production, blocksService.validate() logs warnings instead of throwing
    if (config.conditions && blocksService) {
      // Update context to include conditions for better error messages
      setBlockErrorContext({
        outletName,
        blockName,
        path,
        conditions: config.conditions,
      });

      try {
        blocksService.validate(config.conditions);
      } catch (error) {
        raiseBlockError(
          `Invalid conditions for block "${blockName}" in outlet "${outletName}": ${error.message}`
        );
      }
    }
  } finally {
    clearBlockErrorContext();
  }
}
