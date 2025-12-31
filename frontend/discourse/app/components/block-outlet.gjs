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
import icon from "discourse/helpers/d-icon";
import {
  validateArgsSchema,
  validateBlockArgs,
} from "discourse/lib/blocks/arg-validation";
import { blockDebugLogger } from "discourse/lib/blocks/debug-logger";
import { raiseBlockError } from "discourse/lib/blocks/error";
import { BLOCK_OUTLETS } from "discourse/lib/registry/blocks";

/**
 * Maps outlet names to their registered block configurations.
 * Each outlet can have exactly one configuration registered.
 *
 * @type {Map<string, {children: Array<Object>}>}
 */
const blockConfigs = new Map();

/**
 * Debug callback for block rendering.
 * Set by dev-tools to wrap blocks with debug overlays.
 *
 * @type {Function|null}
 */
let blockDebugCallback = null;

/**
 * Callback for checking if console logging is enabled.
 * Set by dev-tools, returns true when block debug logging is active.
 *
 * @type {Function|null}
 */
let blockLoggingCallback = null;

/**
 * Callback for checking if outlet boundaries should be shown.
 * Set by dev-tools, returns true when outlet boundary overlay is active.
 *
 * @type {Function|null}
 */
let blockOutletBoundaryCallback = null;

/**
 * Sets a callback for debug overlay injection.
 * Called by dev-tools to wrap rendered blocks with debug info.
 *
 * @param {Function} callback - Callback receiving (blockData, context)
 */
export function _setBlockDebugCallback(callback) {
  blockDebugCallback = callback;
}

/**
 * Sets a callback for checking if console logging is enabled.
 * Called by dev-tools to provide state access without window globals.
 *
 * @param {Function} callback - Callback returning boolean
 */
export function _setBlockLoggingCallback(callback) {
  blockLoggingCallback = callback;
}

/**
 * Sets a callback for checking if outlet boundaries should be shown.
 * Called by dev-tools to provide state access without window globals.
 *
 * @param {Function} callback - Callback returning boolean
 */
export function _setBlockOutletBoundaryCallback(callback) {
  blockOutletBoundaryCallback = callback;
}

/**
 * Clears all registered block configurations.
 *
 * USE ONLY FOR TESTING PURPOSES.
 */
export function resetBlockConfigsForTesting() {
  if (DEBUG) {
    blockConfigs.clear();
  }
}

/**
 * Reserved argument names that cannot be used in block configurations.
 * These are used internally by the block system and would conflict with
 * user-provided args. Names starting with underscore are also reserved.
 */
const RESERVED_ARG_NAMES = Object.freeze([
  "classNames",
  "outletName",
  "children",
  "conditions",
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
 * @param {string} [options.description] - Human-readable description of the block
 * @param {Object.<string, ArgSchema>} [options.args] - Schema for block arguments
 * @returns {function(typeof Component): typeof Component} Decorator function
 *
 * @typedef {Object} ArgSchema
 * @property {"string"|"number"|"boolean"|"array"} type - The argument type (required)
 * @property {boolean} [required=false] - Whether the argument is required
 * @property {*} [default] - Default value for the argument
 * @property {"string"|"number"|"boolean"} [itemType] - Item type for array arguments (no nested arrays)
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
 *
 * @example
 * // Block with metadata and arg schema
 * @block("hero-banner", {
 *   description: "A hero banner with customizable title and call-to-action",
 *   args: {
 *     title: { type: "string", required: true },
 *     ctaText: { type: "string", default: "Learn More" },
 *     count: { type: "number" },
 *     showImage: { type: "boolean" },
 *     tags: { type: "array", itemType: "string" },
 *   }
 * })
 * class HeroBanner extends Component { ... }
 */
export function block(name, options = {}) {
  const isContainer = options?.container ?? false;
  const description = options?.description ?? "";
  const argsSchema = options?.args ?? null;

  // Validate arg schema at decoration time
  validateArgsSchema(argsSchema, name);

  return function (target) {
    if (!(target.prototype instanceof Component)) {
      raiseBlockError("@block target must be a Glimmer component class");
      return target; // Return original in production to avoid crash
    }

    return class extends target {
      static blockName = name;
      /**
       * Block metadata including description, container status, and args schema.
       * Used for introspection, documentation, and runtime validation.
       *
       * @type {{description: string, container: boolean, args: Object|null}}
       */
      static blockMetadata = Object.freeze({
        description,
        container: isContainer,
        args: argsSchema ? Object.freeze(argsSchema) : null,
      });
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
       * For child blocks (non-root), this returns an empty array because their
       * configuration is managed by their parent block.
       *
       * @returns {Array<Object>} The block configurations, or an empty array for non-root blocks.
       */
      get config() {
        return this.isRoot ? super.config : [];
      }

      /**
       * Processes and returns child blocks as renderable components.
       * Only container blocks have children. The children are curried components
       * with all necessary args pre-bound.
       *
       * Blocks with conditions are filtered based on condition evaluation.
       * When visual debug overlay is enabled, ghost blocks are included for
       * blocks that fail their conditions.
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
        const blocksService = owner.lookup("service:blocks");
        // Use callback to check logging state (set by dev-tools via closure)
        const isLoggingEnabled = blockLoggingCallback?.() ?? false;
        // For root blocks (BlockOutlet), use the actual outlet name
        // For nested container blocks, use the outletName passed from parent
        const outletName = this.isRoot
          ? this.outletName
          : this.args.outletName || name;
        // Build hierarchy path for debug logging (e.g., "outlet-name/parent-block")
        // For nested blocks, include this container's name in the path
        const hierarchy = this.isRoot
          ? this.outletName
          : `${this.args._hierarchy || this.args.outletName}/${name}`;
        const result = [];

        for (const blockConfig of rawChildren) {
          const blockName = blockConfig.block?.blockName || "unknown";
          let conditionsPassed = true;

          // Evaluate conditions if present
          if (blockConfig.conditions) {
            if (isLoggingEnabled) {
              blockDebugLogger.startGroup(blockName, hierarchy);
            }

            conditionsPassed = blocksService.evaluate(blockConfig.conditions, {
              debug: isLoggingEnabled,
            });

            if (isLoggingEnabled) {
              blockDebugLogger.endGroup(conditionsPassed);
            }
          }

          if (conditionsPassed) {
            // Block passed conditions - render it
            result.push(
              this.#createChildBlock(blockConfig, owner, {
                outletName,
                conditions: blockConfig.conditions,
              })
            );
          } else if (blockDebugCallback) {
            // Block failed conditions - show ghost if debug overlay is enabled
            const ghostData = blockDebugCallback(
              {
                name: blockName,
                Component: null,
                args: blockConfig.args,
                conditions: blockConfig.conditions,
                conditionsPassed: false,
              },
              { outletName }
            );
            if (ghostData?.Component) {
              result.push(ghostData);
            }
          }
        }

        return result;
      }

      /**
       * The registered name of this block.
       *
       * @returns {string}
       */
      get name() {
        return name;
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
       * @param {Object} [debugContext] - Debug context for visual overlay
       * @param {string} [debugContext.outletName] - The outlet name
       * @param {Object} [debugContext.conditions] - The block's conditions
       * @returns {{Component: import("ember-curry-component").CurriedComponent}}
       */
      #createChildBlock(blockConfig, owner, debugContext = {}) {
        const {
          block: ComponentClass,
          args = {},
          classNames,
          children: nestedChildren,
        } = blockConfig;
        const isChildContainer = ComponentClass[__BLOCK_CONTAINER_FLAG];

        // Apply default values from metadata before building args
        const argsWithDefaults = this.#applyArgDefaults(ComponentClass, args);

        // Container blocks receive classNames directly (they handle their own wrapper).
        // Non-container blocks get classNames passed to wrapBlockLayout instead.
        const blockArgs = isChildContainer
          ? this.#buildBlockArgs(argsWithDefaults, nestedChildren, {
              classNames,
            })
          : this.#buildBlockArgs(argsWithDefaults, nestedChildren);

        // Curry the component with pre-bound args so it can be rendered
        // without knowing its configuration details
        const curried = curryComponent(ComponentClass, blockArgs, owner);

        // Container blocks handle their own layout wrapper (they need access
        // to classNames for their container element). Non-container blocks
        // get wrapped in WrappedBlockLayout for consistent block styling.
        let wrappedComponent = isChildContainer
          ? curried
          : wrapBlockLayout(
              {
                classNames,
                name: ComponentClass.blockName,
                Component: curried,
              },
              owner
            );

        // Apply debug callback if present (for visual overlay)
        if (blockDebugCallback) {
          const debugResult = blockDebugCallback(
            {
              name: ComponentClass.blockName,
              Component: wrappedComponent,
              args: argsWithDefaults,
              conditions: debugContext.conditions,
              conditionsPassed: true,
            },
            { outletName: debugContext.outletName }
          );
          if (debugResult?.Component) {
            wrappedComponent = debugResult.Component;
          }
        }

        return { Component: wrappedComponent };
      }

      /**
       * Applies default values from block metadata to provided args.
       * Only applies defaults for args that are undefined.
       *
       * @param {typeof Component} ComponentClass - The block component class
       * @param {Object} providedArgs - User-provided args from block config
       * @returns {Object} Args with defaults applied
       */
      #applyArgDefaults(ComponentClass, providedArgs) {
        const schema = ComponentClass.blockMetadata?.args;
        if (!schema) {
          return providedArgs;
        }

        const result = { ...providedArgs };
        for (const [argName, argDef] of Object.entries(schema)) {
          if (result[argName] === undefined && argDef.default !== undefined) {
            result[argName] = argDef.default;
          }
        }
        return result;
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
        // Build hierarchy for nested blocks
        // Root BlockOutlet doesn't add itself to the hierarchy (it's just the outlet name)
        // Nested container blocks append their name to form the path
        const childHierarchy = this.isRoot
          ? this.outletName
          : `${this.args._hierarchy || this.args.outletName}/${name}`;

        return {
          ...args,
          children,
          outletName: this.args.outletName,
          _hierarchy: childHierarchy, // Pass hierarchy to children for debug logging
          $block$: __BLOCK_CONTAINER_FLAG, // Pass the secret symbol to authorize child block instantiation
          ...extra,
        };
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
  return !!component?.[__BLOCK_FLAG];
}

/**
 * Checks if a component is registered as a container block.
 *
 * @param {Function} component - The component to check
 * @returns {boolean} True if the component is registered as a container block, false otherwise
 */
function isContainerBlock(component) {
  return !!component?.[__BLOCK_CONTAINER_FLAG];
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
 * @param {Array<Object>|Object} [config[].conditions] - Conditions that must pass for block to render
 * @param {Object} [owner] - The application owner for service lookup (passed from plugin API)
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
 *   },
 *   {
 *     block: AdminBanner,
 *     args: { title: "Admin Only" },
 *     conditions: [
 *       { type: "user", admin: true }
 *     ]
 *   }
 * ]);
 * ```
 */
export function renderBlocks(outletName, config, owner) {
  // Lock the block registry on first renderBlocks call.
  // This prevents themes/plugins from registering new blocks after
  // the first configuration is set up.
  const { _lockBlockRegistry } = require("discourse/lib/blocks/registration");
  _lockBlockRegistry();

  // Get blocks service for condition validation if owner is provided
  const blocksService = owner?.lookup("service:blocks");

  validateConfig(config, outletName, blocksService);

  if (blockConfigs.has(outletName)) {
    raiseBlockError(
      `Block outlet "${outletName}" already has a configuration registered.`
    );
  }

  blockConfigs.set(outletName, { children: config });
}

/**
 * Recursively validates an array of block configurations.
 * Validates each block and traverses nested children configurations.
 *
 * @param {Array<Object>} blocksConfig - Block configurations to validate
 * @param {string} outletName - The outlet these blocks belong to
 * @param {import("discourse/services/blocks").default} [blocksService] - Service for validating conditions
 * @throws {Error} If any block configuration is invalid
 */
function validateConfig(blocksConfig, outletName, blocksService) {
  for (const blockConfig of blocksConfig) {
    // Validate the block itself (whether it has children or not)
    validateBlock(blockConfig, outletName, blocksService);

    // Recursively validate nested children
    if (blockConfig.children) {
      validateConfig(blockConfig.children, outletName, blocksService);
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
 * - Conditions are valid (if blocksService is provided)
 *
 * @param {Object} config - The block configuration object
 * @param {typeof Component} config.block - The block component class
 * @param {string} [config.name] - Display name for error messages
 * @param {Object} [config.args] - Args to pass to the block
 * @param {Array<Object>} [config.children] - Nested block configurations
 * @param {Array<Object>|Object} [config.conditions] - Conditions for rendering
 * @param {string} outletName - The outlet this block belongs to
 * @param {import("discourse/services/blocks").default} [blocksService] - Service for validating conditions
 * @throws {Error} If validation fails
 */
function validateBlock(config, outletName, blocksService) {
  if (!BLOCK_OUTLETS.includes(outletName)) {
    raiseBlockError(`Unknown block outlet: ${outletName}`);
    return;
  }

  if (!config.block) {
    raiseBlockError(
      `Block in layout for \`${outletName}\` is missing a component: ${JSON.stringify(config)}`
    );
    return;
  }

  if (!isBlock(config.block)) {
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

  const hasChildren = config.children?.length > 0;
  const isContainer = isContainerBlock(config.block);

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
    try {
      blocksService.validate(config.conditions);
    } catch (error) {
      raiseBlockError(
        `Invalid conditions for block "${config.block.blockName || config.name}" in outlet "${outletName}": ${error.message}`
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
    raiseBlockError(
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
      raiseBlockError(
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

  /**
   * Whether to show outlet boundary debug overlay.
   * Checked via callback to dev-tools state.
   *
   * @returns {boolean}
   */
  get showOutletBoundary() {
    return blockOutletBoundaryCallback?.() ?? false;
  }

  <template>
    {{! Yield to :before block with hasConfig boolean for conditional rendering }}
    {{yield (hasConfig this.outletName) to="before"}}

    {{#if this.showOutletBoundary}}
      <div class="block-outlet-debug">
        <span class="block-outlet-debug__badge">{{icon "cubes"}}
          {{this.outletName}}
        </span>
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
      </div>
    {{else if this.children}}
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
