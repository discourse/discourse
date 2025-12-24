import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { service } from "@ember/service";
import curryComponent from "ember-curry-component";
import concatClass from "discourse/helpers/concat-class";
import { BLOCK_OUTLETS } from "discourse/lib/registry/blocks";
import { or } from "discourse/truth-helpers";

// TODO: This should be stored in a service instead
const blockConfigs = new Map();

// IMPORTANT: do not export these symbols
// These secret symbols allow us to identify block components. We use them to ensure
// only block components can be rendered inside BlockOutlets, and that block components
// cannot be rendered in another context.
const _BLOCK_FLAG = Symbol("block");
const _BLOCK_CONTAINER_FLAG = Symbol("block-container");

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
export function block(name, options = {}) {
  return function (target) {
    const { container: isContainer = false } = options;

    return class extends target {
      static blockName = name;

      static [_BLOCK_FLAG] = true;
      static [_BLOCK_CONTAINER_FLAG] = isContainer;

      constructor() {
        super(...arguments);
        if (!this.args[_BLOCK_CONTAINER_FLAG]) {
          throw new Error(
            `Block components cannot be used directly in templates. They can only be rendered directly inside BlockOutlets or BlockContainers.`
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
  return !!component[_BLOCK_FLAG];
}

function isContainerBlock(component) {
  return !!component[_BLOCK_CONTAINER_FLAG];
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
 * renderBlocks(myFrame, [
 *   { block: MyBlockComponent, outletName: "my-block" }
 * ]);
 * ```
 */
export function renderBlocks(outletName, config) {
  validateConfig(outletName, config);

  BlockOutlet.renderInto(outletName, config);
}

function validateConfig(outletName, blocksConfig) {
  blocksConfig.forEach((blockConfig) => {
    if (blockConfig.children) {
      validateConfig(blockConfig.children);
    } else {
      validateBlock(blockConfig, outletName);
    }
  });
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
function hasConfig(outletName) {
  return blockConfigs.has(outletName);
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
 * validateBlock({
 *   block: MyBlockComponent,
 *   outletName: "my-block"
 * });
 * ```
 */
function validateBlock(config, outletName) {
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

  if (config?.children?.length > 0 && !isContainerBlock(config.block)) {
    throw new Error(
      `Block component ${config.name} (${config.block}) in layout ${outletName} cannot have children`
    );
  }

  if (isContainerBlock(config.block) && config?.children?.length === 0) {
    throw new Error(
      `Block component ${config.name} (${config.block}) in layout ${outletName} must have children`
    );
  }
}

export default class BlockOutlet extends Component {
  @service discovery;

  get blocks() {
    const blocks = blockConfigs.get(this.args.name);

    if (!blocks) {
      return [];
    }

    const resolvedBlocks = [];

    for (const item of blocks) {
      if (item.type === "conditional") {
        const shouldRender =
          (item.routes.includes("discovery") &&
            this.discovery.onDiscoveryRoute &&
            !this.discovery.custom) ||
          (item.routes.includes("homepage") && this.discovery.custom) ||
          (item.routes.includes("category") && this.discovery.category) ||
          (item.routes.includes("top-menu") &&
            this.discovery.onDiscoveryRoute &&
            !this.discovery.category &&
            !this.discovery.tag &&
            !this.discovery.custom);

        if (shouldRender) {
          resolvedBlocks.push(...item.blocks);
        }
      } else {
        resolvedBlocks.push(item);
      }
    }

    return resolvedBlocks;
  }

  get shouldShow() {
    return this.blocks.length > 0;
  }

  <template>
    {{yield (hasConfig @name) to="before"}}
    {{#if this.shouldShow}}
      <div class={{@name}}>
        <div class={{concat @name "__container"}}>
          <div class={{concat @name "__layout"}}>
            {{#each this.blocks as |config|}}
              <WrappedBlock
                @[_BLOCK_CONTAINER_FLAG]={{true}}
                @outletName={{@name}}
                @config={{config}}
              />
            {{/each}}
          </div>
        </div>
      </div>
    {{/if}}
    {{yield (hasConfig @name) to="after"}}
  </template>
}

const WrappedBlock = <template>
  <div
    class={{concatClass
      (concat @blockOutlet "__block ")
      (concat "block-" @block.block.blockName)
      @block.customClass
    }}
  >
    {{#let
      (curryComponent @block.block (or @block.args (hash)))
      as |BlockComponent|
    }}
      <BlockComponent />
    {{/let}}
  </div>
</template>;
