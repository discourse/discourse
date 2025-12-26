/**
 * BlockOutlet System
 *
 * This module provides a secure block rendering system for Discourse. Blocks are
 * special components that can only be rendered within designated BlockOutlet areas,
 * preventing misuse and ensuring consistent rendering behavior.
 *
 * Key concepts:
 * - BlockOutlet: A designated area in the UI where blocks can be rendered
 * - Block: A component decorated with @block that can only render inside BlockOutlets
 * - Container Block: A block that can contain nested child blocks
 *
 * Security model:
 * - Blocks use secret symbols to verify they're being rendered in authorized contexts
 * - Direct template usage of blocks (outside BlockOutlets) throws an error
 * - This prevents plugins from bypassing the block system's validation
 */
import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { cached } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { getOwner } from "@ember/owner";
import curryComponent from "ember-curry-component";
import concatClass from "discourse/helpers/concat-class";
import { BLOCK_OUTLETS } from "discourse/lib/registry/blocks";
import { consolePrefix } from "discourse/lib/source-identifier";

/**
 * Maps outlet names to their registered block configurations.
 * Each outlet can have exactly one configuration registered.
 *
 * @type {Map<string, {children: Array<Object>}>}
 */
const blockConfigs = new Map();

/**
 * Reserved argument names that cannot be used in block configurations.
 * These are used internally by the block system and would conflict with
 * user-provided args. Names starting with underscore are also reserved.
 */
const RESERVED_ARG_NAMES = Object.freeze([
  "classNames",
  "outletName",
  "children",
  "$block$",
]);

// ============================================================================
// Security Symbols
// ============================================================================
//
// IMPORTANT: These symbols MUST NOT be exported.
//
// These secret symbols form the core of the block security model. They allow
// the system to verify that:
// 1. A component was decorated with @block (has __BLOCK_FLAG)
// 2. A component is authorized to contain children (has __BLOCK_CONTAINER_FLAG)
// 3. A block is being rendered in an authorized context (via $block$ arg)
//
// By keeping these symbols private, we prevent external code from spoofing
// block authorization or bypassing validation.
const __BLOCK_FLAG = Symbol("block");
const __BLOCK_CONTAINER_FLAG = Symbol("block-container");

/**
 * Decorator that transforms a Glimmer component into a block component.
 *
 * Block components have special security constraints:
 * - They can only be rendered inside BlockOutlets or container blocks
 * - They cannot be used directly in templates
 * - They receive special args for authorization and hierarchy management
 *
 * @param {string} name - Unique identifier for the block (e.g., "hero-banner", "sidebar-panel")
 * @param {Object} [options] - Configuration options
 * @param {boolean} [options.container=false] - If true, this block can contain nested child blocks
 * @returns {function(typeof Component): typeof Component} Decorator function
 *
 * @example
 * // Simple block
 * @block("my-card")
 * class MyCard extends Component {
 *   <template>
 *     <div class="card">{{@title}}</div>
 *   </template>
 * }
 *
 * @example
 * // Container block that can hold children
 * @block("my-section", { container: true })
 * class MySection extends Component {
 *   <template>
 *     <section>
 *       {{#each this.children as |child|}}
 *         <child.Component />
 *       {{/each}}
 *     </section>
 *   </template>
 * }
 */
export function block(name, options = {}) {
  const isContainer = options?.container ?? false;

  return function (target) {
    if (!(target.prototype instanceof Component)) {
      throw new Error("@block target must be a Glimmer component class");
    }

    return class extends target {
      static blockName = name;
      static [__BLOCK_FLAG] = true;
      static [__BLOCK_CONTAINER_FLAG] = isContainer;

      constructor() {
        super(...arguments);

        // Authorization check: blocks can only be instantiated in two scenarios:
        // 1. As a root block (BlockOutlet sets __ROOT_BLOCK static property)
        // 2. As a child of a container block (parent passes $block$ secret symbol)
        const isAuthorized =
          this.isRoot || this.args.$block$ === __BLOCK_CONTAINER_FLAG;

        if (!isAuthorized) {
          throw new Error(
            `Block components cannot be used directly in templates. ` +
              `They can only be rendered inside BlockOutlets or container blocks.`
          );
        }
      }

      /**
       * Indicates if this block is the root of a block tree (i.e., a BlockOutlet).
       *
       * @returns {boolean}
       */
      get isRoot() {
        return this.constructor.__ROOT_BLOCK === __BLOCK_CONTAINER_FLAG;
      }

      /**
       * Returns the raw block configuration. Only meaningful for root blocks.
       *
       * @returns {Array<Object>}
       */
      get config() {
        return this.isRoot ? super.config : [];
      }

      /**
       * Processes and returns child blocks as renderable components.
       * Only container blocks have children. The children are curried components
       * with all necessary args pre-bound.
       *
       * @returns {Array<{Component: import("ember-curry-component").CurriedComponent}>|undefined}
       */
      @cached
      get children() {
        const rawChildren = this.isRoot ? super.children : this.args.children;
        if (!isContainer || !rawChildren) {
          return;
        }

        const owner = getOwner(this);
        return rawChildren.map((blockConfig) =>
          this.#createChildBlock(blockConfig, owner)
        );
      }

      /**
       * Creates a renderable child block from a block configuration.
       * Curries the component with all necessary args and wraps non-container
       * blocks in a layout wrapper for consistent styling.
       *
       * @param {Object} blockConfig - The block configuration
       * @param {typeof Component} blockConfig.block - The block component class
       * @param {Object} [blockConfig.args] - Args to pass to the block
       * @param {string} [blockConfig.classNames] - Additional CSS classes
       * @param {Array<Object>} [blockConfig.children] - Nested block configs
       * @param {import("@ember/owner").default} owner - The application owner
       * @returns {{Component: import("ember-curry-component").CurriedComponent}}
       */
      #createChildBlock(blockConfig, owner) {
        const {
          block: ComponentClass,
          args = {},
          classNames,
          children: nestedChildren,
        } = blockConfig;
        const isChildContainer = ComponentClass[__BLOCK_CONTAINER_FLAG];

        // Container blocks receive classNames directly (they handle their own wrapper).
        // Non-container blocks get classNames passed to wrapBlockLayout instead.
        const blockArgs = isChildContainer
          ? this.#buildBlockArgs(args, nestedChildren, { classNames })
          : this.#buildBlockArgs(args, nestedChildren);

        // Curry the component with pre-bound args so it can be rendered
        // without knowing its configuration details
        const curried = curryComponent(ComponentClass, blockArgs, owner);

        return {
          // Container blocks handle their own layout wrapper (they need access
          // to classNames for their container element). Non-container blocks
          // get wrapped in WrappedBlockLayout for consistent block styling.
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

      /**
       * Builds the args object to pass to a child block.
       * Merges user-provided args with internal system args and any extra properties.
       *
       * @param {Object} args - User-provided args from block config
       * @param {Array<Object>|undefined} children - Nested children configs
       * @param {Object} [extra] - Additional properties to include (e.g., { classNames })
       * @returns {Object} The complete args object for the child block
       */
      #buildBlockArgs(args, children, extra = {}) {
        return {
          ...args,
          children,
          outletName: this.args.outletName,
          // Pass the secret symbol to authorize child block instantiation
          $block$: __BLOCK_CONTAINER_FLAG,
          ...extra,
        };
      }

      /**
       * The registered name of this block.
       *
       * @returns {string}
       */
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
 * Registers block configurations for a named outlet.
 *
 * This is the main entry point for plugins to render blocks in designated areas.
 * Each outlet can only have one configuration registered. In development mode,
 * attempting to register a second configuration throws an error; in production,
 * it logs a warning.
 *
 * @param {string} outletName - The outlet identifier (must be in BLOCK_OUTLETS)
 * @param {Array<Object>} config - Array of block configurations
 * @param {typeof Component} config[].block - The block component class (must use @block decorator)
 * @param {Object} [config[].args] - Args to pass to the block component
 * @param {string} [config[].classNames] - Additional CSS classes for the block wrapper
 * @param {Array<Object>} [config[].children] - Nested blocks (only for container blocks)
 * @throws {Error} If validation fails or outlet already has a config (in DEBUG mode)
 *
 * @example
 * ```js
 * import { renderBlocks } from "discourse/components/block-outlet";
 *
 * renderBlocks("homepage-blocks", [
 *   { block: HeroBanner, args: { title: "Welcome" } },
 *   {
 *     block: BlockGroup,
 *     children: [
 *       { block: FeatureCard, args: { icon: "star" } },
 *       { block: FeatureCard, args: { icon: "heart" } },
 *     ]
 *   }
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
 * Recursively validates an array of block configurations.
 * Validates each block and traverses nested children configurations.
 *
 * @param {Array<Object>} blocksConfig - Block configurations to validate
 * @param {string} outletName - The outlet these blocks belong to
 * @throws {Error} If any block configuration is invalid
 */
function validateConfig(blocksConfig, outletName) {
  for (const blockConfig of blocksConfig) {
    // Validate the block itself (whether it has children or not)
    validateBlock(blockConfig, outletName);

    // Recursively validate nested children
    if (blockConfig.children) {
      validateConfig(blockConfig.children, outletName);
    }
  }
}

/**
 * Checks if blocks have been registered for a given outlet.
 * Used in templates to conditionally render content based on block presence.
 *
 * @param {string} outletName - The outlet identifier to check
 * @returns {boolean} True if blocks are registered for this outlet
 */
function hasConfig(outletName) {
  return blockConfigs.has(outletName);
}

/**
 * Validates a single block configuration object.
 * Performs comprehensive validation including:
 * - Outlet name is registered in BLOCK_OUTLETS
 * - Block component exists and is decorated with @block
 * - Container/children relationship is valid
 * - No reserved arg names are used
 *
 * @param {Object} config - The block configuration object
 * @param {typeof Component} config.block - The block component class
 * @param {string} [config.name] - Display name for error messages
 * @param {Object} [config.args] - Args to pass to the block
 * @param {Array<Object>} [config.children] - Nested block configurations
 * @param {string} outletName - The outlet this block belongs to
 * @throws {Error} If validation fails
 */
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
 * Checks if an argument name is reserved for internal use.
 * Reserved names include explicit names in RESERVED_ARG_NAMES and
 * any name starting with underscore (private by convention).
 *
 * @param {string} argName - The argument name to check
 * @returns {boolean} True if the name is reserved
 */
function isReservedArgName(argName) {
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
function validateReservedArgs(config, outletName) {
  if (!config.args) {
    return;
  }

  const usedReservedArgs = Object.keys(config.args).filter(isReservedArgName);

  if (usedReservedArgs.length > 0) {
    throw new Error(
      `Block ${config.name} in layout ${outletName} uses reserved arg names: ${usedReservedArgs.join(", ")}. ` +
        `Names starting with underscore are reserved for internal use.`
    );
  }
}

/**
 * Root component for rendering registered blocks in a designated outlet.
 *
 * BlockOutlet serves as the entry point for the block rendering system. It:
 * - Looks up registered block configurations by outlet name
 * - Renders blocks in a consistent wrapper structure
 * - Provides named blocks (:before, :after) for conditional content
 *
 * @component BlockOutlet
 * @param {string} @name - The outlet identifier (must be registered in BLOCK_OUTLETS)
 *
 * @example
 * ```hbs
 * <BlockOutlet @name="homepage-blocks">
 *   <:after as |hasBlocks|>
 *     {{#unless hasBlocks}}
 *       <p>No blocks configured</p>
 *     {{/unless}}
 *   </:after>
 * </BlockOutlet>
 * ```
 */
@block("block-outlet", { container: true })
export default class BlockOutlet extends Component {
  /**
   * The outlet name, locked at construction time.
   * This prevents dynamic name changes which could cause inconsistent rendering.
   *
   * @type {string}
   */
  #name;

  /**
   * Marks this class as a root block, allowing it to bypass the normal
   * authorization check in the @block decorator's constructor.
   *
   * @type {symbol}
   */
  static __ROOT_BLOCK = __BLOCK_CONTAINER_FLAG;

  constructor() {
    super(...arguments);

    // Lock the name at construction to prevent dynamic changes
    this.#name = this.args.name;

    if (!BLOCK_OUTLETS.includes(this.#name)) {
      throw new Error(
        `Block outlet ${this.#name} is not registered in the blocks registry`
      );
    }
  }

  /**
   * Returns the raw block configurations registered for this outlet.
   * The @block decorator's children getter transforms these into renderable components.
   *
   * @returns {Array<Object>} Block configurations, or empty array if none registered
   */
  get children() {
    return blockConfigs.get(this.#name)?.children ?? [];
  }

  /**
   * The locked outlet name, used for CSS class generation and config lookup.
   *
   * @returns {string}
   */
  get outletName() {
    return this.#name;
  }

  <template>
    {{! Yield to :before block with hasConfig boolean for conditional rendering }}
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

    {{! Yield to :after block with hasConfig boolean for conditional rendering }}
    {{yield (hasConfig this.outletName) to="after"}}
  </template>
}

/**
 * Wraps a non-container block in a standard layout wrapper.
 * This provides consistent styling and class naming for all blocks.
 *
 * @param {Object} blockData - Block rendering data
 * @param {string} blockData.name - The block's registered name
 * @param {string} [blockData.classNames] - Additional CSS classes
 * @param {import("ember-curry-component").CurriedComponent} blockData.Component - The curried block component
 * @param {import("@ember/owner").default} owner - The application owner for currying
 * @returns {import("ember-curry-component").CurriedComponent} Wrapped component
 */
function wrapBlockLayout(blockData, owner) {
  return curryComponent(WrappedBlockLayout, blockData, owner);
}

/**
 * Template-only component that wraps non-container blocks.
 * Generates BEM-style class names:
 * - `{outletName}__block` - Identifies this as a block within the outlet
 * - `block-{name}` - Identifies the specific block type
 * - Custom classNames from configuration
 */
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
