// This secret symbol allows us to identify block components. We use this to ensure
// only block components can be rendered inside BlockOutlets, and that block components
// cannot be rendered in another context.
import { DEBUG } from "@glimmer/env";
import { BLOCK_OUTLETS } from "discourse/lib/registry/blocks";

// Performing checks in the blocks registry
BLOCK_OUTLETS.forEach((name) => {
  if (DEBUG) {
    if (name !== name.toLowerCase()) {
      throw new Error(`Block outlet name "${name}" must be lowercase.`);
    }
  }
});

export const _BLOCK_IDENTIFIER = Symbol("block secret");

// TODO: This should be stored in a service instead
const blockConfigs = new Map();

/**
 * A decorator that registers a component as a block.
 * Adds a `blockName` property to the target and registers it in the blocks registry.
 * The decorated component can only be rendered inside BlockOutlets.
 *
 * @param {string} name - The name to assign to the block
 * @returns {function(Function): Function} A decorator function that accepts a class/component target
 *
 * @example
 * ```js
 * @block("my-custom-block")
 * class MyBlock {
 *   // ...
 * }
 * ```
 */
export function block(name) {
  return function (target) {
    return class extends target {
      static blockName = name;
      static [_BLOCK_IDENTIFIER] = true;

      constructor() {
        super(...arguments);
        if (this.args._block_identifier !== _BLOCK_IDENTIFIER) {
          throw new Error(
            `Block components cannot be used directly in templates. They can only be rendered directly inside BlockOutlets.`
          );
        }
      }
    };
  };
}

/**
 * Checks if a component is registered as a block.
 *
 * @param {Function} component - The component to check
 * @returns {boolean} True if the component is registered as a block, false otherwise
 */
export function isBlock(component) {
  return component[_BLOCK_IDENTIFIER];
}

/**
 * Registers and validates block configurations for a given frame.
 * Iterates through all block configs, handling groups and conditional blocks,
 * validates each block configuration, and stores the configuration in the blockConfigs map.
 *
 * @param {*} outletName - The frame identifier to associate with the block configurations
 * @param {Array<Object>} config - Array of block configuration objects to validate and store
 * @param {Function} config[].block - The block component
 * @param {string} [config[].outletName] - The outletName of the block
 * @param {boolean} [config[].group] - Whether this is a group of blocks
 * @param {Array<Object>} [config[].blocks] - Nested blocks when group is true
 * @param {string} [config[].type] - The type of block (e.g., "conditional")
 * @throws {Error} If any block configuration is invalid
 *
 * @example
 * ```js
 * renderBlocksConfig(myFrame, [
 *   { block: MyBlockComponent, outletName: "my-block" }
 * ]);
 * ```
 */
export function renderBlocksConfig(outletName, config) {
  // TODO: Better validation
  config.forEach((blockConfig) => {
    if (blockConfig.group) {
      blockConfig.blocks.forEach((item) =>
        validateBlockConfig(item, outletName)
      );
    } else if (blockConfig.type === "conditional") {
      blockConfig.blocks.forEach((conditionalBlock) => {
        if (conditionalBlock.group) {
          conditionalBlock.blocks.forEach((item) =>
            validateBlockConfig(item, outletName)
          );
        } else {
          validateBlockConfig(conditionalBlock, outletName);
        }
      });
    } else {
      validateBlockConfig(blockConfig, outletName);
    }
  });

  blockConfigs.set(outletName, config);
}

/**
 * Validates a block configuration object.
 * Ensures the block has a component and that the component is registered as a valid block.
 *
 * @param {Object} config - The block configuration object to validate
 * @param {Function} config.block - The block component to validate
 * @param {string} outletName - The outletName of the block for error messages
 * @throws {Error} If the block is missing a component or if the component is not a valid block
 *
 * @example
 * ```js
 * validateBlockConfig({
 *   block: MyBlockComponent,
 *   outletName: "my-block"
 * });
 * ```
 */
function validateBlockConfig(config, outletName) {
  if (!BLOCK_OUTLETS.includes(outletName)) {
    throw new Error(
      `Block outlet \`${outletName}\` is not registered in the blocks registry`
    );
  }

  if (!config.block) {
    throw new Error(`Block in layout ${outletName} is missing a component`);
  }
  if (!isBlock(config.block)) {
    throw new Error(
      `Block component ${config.name} (${config.block}) in layout ${outletName} is not a valid block`
    );
  }
}

/**
 * Checks if a block configuration exists for the given outlet name.
 *
 * @param {string} outletName - The name of the outlet to check for configuration
 * @returns {boolean} True if a configuration exists for the outlet, false otherwise
 *
 * @example
 * ```js
 * if (hasConfig("my-outlet")) {
 *   // Block configuration exists for this outlet
 * }
 * ```
 */
export function hasConfig(outletName) {
  return blockConfigs.has(outletName);
}
