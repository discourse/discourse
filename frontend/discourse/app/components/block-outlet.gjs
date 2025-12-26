import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { cached } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { getOwner } from "@ember/owner";
import curryComponent from "ember-curry-component";
import concatClass from "discourse/helpers/concat-class";
import { BLOCK_OUTLETS } from "discourse/lib/registry/blocks";
import { consolePrefix } from "discourse/lib/source-identifier";

const blockConfigs = new Map();

// IMPORTANT: do not export these symbols
// These secret symbols allow us to identify block components. We use them to ensure
// only block components can be rendered inside BlockOutlets, and that block components
// cannot be rendered in another context.
const __BLOCK_FLAG = Symbol("block");
const __BLOCK_CONTAINER_FLAG = Symbol("block-container");

/**
 * A decorator that registers a component as a block.
 * Adds a `blockName` property to the target and registers it in the blocks registry.
 * The decorated component can only be rendered inside BlockOutlets.
 *
 * @param {string} name - The name to assign to the block
 * @param {Object} [options] - Block options
 * @param {boolean} [options.container] - Whether this block is a container for other blocks
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
  const isContainer = options?.container ?? false;

  return function (target) {
    // ensure target is a Glimmer component class
    if (!(target.prototype instanceof Component)) {
      throw new Error("@block target must be a Glimmer component class");
    }

    return class extends target {
      static blockName = name;
      static [__BLOCK_FLAG] = true;
      static [__BLOCK_CONTAINER_FLAG] = isContainer;

      constructor() {
        super(...arguments);
        const isAuthorized =
          this.isRoot || this.args.$block$ === __BLOCK_CONTAINER_FLAG;

        if (!isAuthorized) {
          throw new Error(
            `Block components cannot be used directly in templates. They can only be rendered directly inside BlockOutlets or BlockContainers.`
          );
        }
      }

      get isRoot() {
        return this.constructor.__ROOT_BLOCK === __BLOCK_CONTAINER_FLAG;
      }

      get config() {
        return this.isRoot ? super.config : [];
      }

      @cached
      get children() {
        const rawChildren = this.isRoot ? super.children : this.args.children;
        if (!isContainer || !rawChildren) {
          return;
        }

        return this.#mapChildBlocks(rawChildren);
      }

      #mapChildBlocks(rawChildren) {
        const owner = getOwner(this);
        return rawChildren.map((blockConfig) =>
          this.#createChildBlock(blockConfig, owner)
        );
      }

      #createChildBlock(blockConfig, owner) {
        const {
          block: ComponentClass,
          args = {},
          classNames,
          children: nestedChildren,
        } = blockConfig;
        const isChildContainer = ComponentClass[__BLOCK_CONTAINER_FLAG];
        const taggedArgs = this.#buildTaggedArgs(
          args,
          nestedChildren,
          classNames,
          isChildContainer
        );
        const curried = curryComponent(ComponentClass, taggedArgs, owner);

        return {
          Component: isChildContainer
            ? curried
            : wrapBlockLayout(
                {
                  classNames,
                  name: ComponentClass.blockName,
                  Component: curried,
                },
                owner
              ),
        };
      }

      #buildTaggedArgs(args, children, classNames, includeClassNames) {
        const base = {
          ...args,
          children,
          outletName: this.args.outletName,
          $block$: __BLOCK_CONTAINER_FLAG,
        };
        return includeClassNames ? { ...base, classNames } : base;
      }

      get name() {
        return name;
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
  return !!component[__BLOCK_FLAG];
}

/**
 * Checks if a component is registered as a container block.
 *
 * @param {Function} component - The component to check
 * @returns {boolean} True if the component is registered as a container block, false otherwise
 */
function isContainerBlock(component) {
  return !!component[__BLOCK_CONTAINER_FLAG];
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
  validateConfig(config, outletName);

  if (blockConfigs.has(outletName)) {
    const errorMessage = [
      consolePrefix(),
      `Block outlet ${outletName} already has a configuration registered.`,
    ].join(" ");

    // block outlets can render only one config per outlet
    if (DEBUG) {
      throw new Error(errorMessage);
    } else {
      // eslint-disable-next-line no-console
      console.warn(errorMessage);
    }
  }

  blockConfigs.set(outletName, { children: config });
}

/**
 * Validates multiple block configurations recursively.
 *
 * @param {Array<Object>} blocksConfig - The array of block configurations to validate
 * @param {string} outletName - The name of the outlet these blocks belong to
 */
function validateConfig(blocksConfig, outletName) {
  blocksConfig.forEach((blockConfig) => {
    if (blockConfig.children) {
      validateConfig(blockConfig.children, outletName);
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
const RESERVED_ARG_NAMES = ["classNames", "outletName", "children", "$block$"];

function validateBlock(config, outletName) {
  if (!BLOCK_OUTLETS.includes(outletName)) {
    throw new Error(`Unknown block outlet: ${outletName}`);
  }

  if (!config.block) {
    throw new Error(
      `Block in layout for \`${outletName}\` is missing a component: ${JSON.stringify(config)}`
    );
  }

  if (!isBlock(config.block)) {
    throw new Error(
      `Block component ${config.name} (${config.block}) in layout ${outletName} is not a valid block`
    );
  }

  const hasChildren = config.children?.length > 0;
  const isContainer = isContainerBlock(config.block);

  if (hasChildren && !isContainer) {
    throw new Error(
      `Block component ${config.name} (${config.block}) in layout ${outletName} cannot have children`
    );
  }

  if (isContainer && !hasChildren) {
    throw new Error(
      `Block component ${config.name} (${config.block}) in layout ${outletName} must have children`
    );
  }

  validateReservedArgs(config, outletName);
}

/**
 * Validates that block config args don't use reserved names.
 *
 * @param {Object} config - The block configuration
 * @param {string} outletName - The outlet name for error messages
 */
function validateReservedArgs(config, outletName) {
  if (!config.args) {
    return;
  }

  const usedReservedArgs = Object.keys(config.args).filter((key) =>
    RESERVED_ARG_NAMES.includes(key)
  );

  if (usedReservedArgs.length > 0) {
    throw new Error(
      `Block ${config.name} in layout ${outletName} uses reserved arg names: ${usedReservedArgs.join(", ")}`
    );
  }
}

/**
 * @component block-outlet
 * @description Renders a named block outlet where other components can be injected.
 * @param {string} @name - The registered name of the block outlet
 */
@block("block-outlet", { container: true })
export default class BlockOutlet extends Component {
  /**
   * The locked name of the outlet.
   *
   * @type {string}
   */
  #name;

  /**
   * @type {symbol}
   */
  static __ROOT_BLOCK = __BLOCK_CONTAINER_FLAG;

  constructor() {
    super(...arguments);

    // locks the initial name argument so it can be changed dynamically later
    this.#name = this.args.name;

    if (!BLOCK_OUTLETS.includes(this.#name)) {
      throw new Error(
        `Block outlet ${this.#name} is not registered in the blocks registry`
      );
    }
  }

  /**
   * @returns {Array<Object>}
   */
  get children() {
    return blockConfigs.get(this.#name)?.children ?? [];
  }

  /**
   * @returns {string}
   */
  get outletName() {
    return this.#name;
  }

  <template>
    {{yield (hasConfig this.outletName) to="before"}}
    {{#if this.children}}
      <div class={{this.outletName}}>
        <div class="{{this.outletName}}__container">
          <div class="{{this.outletName}}__layout">
            {{#each this.children as |item|}}
              <item.Component @outletName={{this.outletName}} />
            {{/each}}
          </div>
        </div>
      </div>
    {{/if}}
    {{yield (hasConfig this.outletName) to="after"}}
  </template>
}

/**
 * @param {Object} blockData - Data for the block to be wrapped
 * @param {import("@ember/owner").default} owner - The application owner
 * @returns {import("ember-curry-component").CurriedComponent} A curried component
 */
function wrapBlockLayout(blockData, owner) {
  return curryComponent(WrappedBlockLayout, blockData, owner);
}

const WrappedBlockLayout = <template>
  <div
    class={{concatClass
      (concat @outletName "__block")
      (concat "block-" @name)
      @classNames
    }}
  >
    <@Component />
  </div>
</template>;
