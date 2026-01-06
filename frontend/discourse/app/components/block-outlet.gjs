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
import { validateArgsSchema } from "discourse/lib/blocks/arg-validation";
import { validateConfig } from "discourse/lib/blocks/config-validation";
import {
  getBlockDebugCallback,
  getOutletInfoComponent,
  isBlockLoggingEnabled,
  isOutletBoundaryEnabled,
} from "discourse/lib/blocks/debug-hooks";
import { blockDebugLogger } from "discourse/lib/blocks/debug-logger";
import { raiseBlockError } from "discourse/lib/blocks/error";
import {
  detectPatternConflicts,
  validateOutletPatterns,
  warnUnknownOutletPatterns,
} from "discourse/lib/blocks/outlet-matcher";
import {
  parseBlockName,
  VALID_NAMESPACED_BLOCK_PATTERN,
} from "discourse/lib/blocks/patterns";
import {
  blockRegistry,
  isBlockFactory,
  resolveBlock,
} from "discourse/lib/blocks/registration";
import { BLOCK_OUTLETS } from "discourse/lib/registry/blocks";

/**
 * Maps outlet names to their registered block configurations.
 * Each outlet can have exactly one configuration registered.
 *
 * @type {Map<string, {children: Array<Object>}>}
 */
const blockConfigs = new Map();

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

// ============================================================================
// Security Symbols
// ============================================================================
//
// IMPORTANT: These symbols MUST NOT be exported.
// DO NOT REFACTOR TO EXTRACT THESE SYMBOLS INTO ANOTHER FILE
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
 * @param {string} name - Unique identifier for the block (e.g., "hero-banner", "sidebar-panel").
 *   Must match pattern: lowercase letters, numbers, hyphens.
 *
 * @param {Object} [options] - Configuration options for the block.
 *
 * @param {boolean} [options.container=false] - If true, this block can contain nested child blocks.
 *   Container blocks MUST have children in their config.
 *
 * @param {string} [options.description] - Human-readable description of the block.
 *   Used for documentation and dev tools.
 *
 * @param {Object.<string, ArgSchema>} [options.args] - Schema for block arguments.
 *
 * @param {string[]} [options.allowedOutlets] - Glob patterns specifying which outlets
 *   this block CAN be rendered in. If specified, the block can ONLY render in outlets
 *   matching at least one pattern. Uses picomatch syntax:
 *   - Exact match: `"sidebar-blocks"` - only this specific outlet
 *   - Wildcard: `"sidebar-*"` - matches sidebar-left, sidebar-right, etc.
 *   - Brace expansion: `"{sidebar,footer}-*"` - matches sidebar-* OR footer-*
 *   - Character class: `"modal-[0-9]"` - matches modal-1, modal-2, etc.
 *   - Negation: `"!(*-debug)"` - matches anything NOT ending in -debug
 *   Namespaced outlets (containing `:`) bypass known-outlet validation:
 *   - `"my-plugin:custom-outlet"` - plugin-defined outlet
 *   - `"my-theme:hero-section"` - theme-defined outlet
 *
 * @param {string[]} [options.deniedOutlets] - Glob patterns specifying which outlets
 *   this block CANNOT be rendered in. If an outlet matches any denied pattern, the
 *   block will not render there. Uses the same picomatch syntax as allowedOutlets.
 *   When both allowedOutlets and deniedOutlets are specified:
 *   - Outlet must match at least one allowed pattern
 *   - Outlet must NOT match any denied pattern
 *   - Conflicting patterns (same outlet in both) cause decoration-time errors
 *
 * @returns {function(typeof Component): typeof Component} Decorator function
 *
 * @typedef {Object} ArgSchema
 * @property {"string"|"number"|"boolean"|"array"} type - The argument type (required)
 * @property {boolean} [required=false] - Whether the argument is required
 * @property {*} [default] - Default value for the argument
 * @property {"string"|"number"|"boolean"} [itemType] - Item type for array arguments (no nested arrays)
 *
 * @example
 * // Simple block with no restrictions
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
 *
 * @example
 * // Block restricted to sidebar outlets only
 * @block("sidebar-widget", {
 *   description: "A widget designed for sidebar placement",
 *   allowedOutlets: ["sidebar-*"],
 *   args: { title: { type: "string", required: true } }
 * })
 * class SidebarWidget extends Component { ... }
 *
 * @example
 * // Block denied from specific outlets
 * @block("full-width-banner", {
 *   description: "Full-width banner that doesn't fit in narrow containers",
 *   deniedOutlets: ["sidebar-*", "modal-*", "tooltip-*"]
 * })
 * class FullWidthBanner extends Component { ... }
 *
 * @example
 * // Block for plugin-defined outlets (namespaced)
 * @block("plugin-dashboard-widget", {
 *   allowedOutlets: ["my-plugin:dashboard", "sidebar-*"]
 * })
 * class PluginDashboardWidget extends Component { ... }
 */
export function block(name, options = {}) {
  // Extract all options with defaults
  const isContainer = options?.container ?? false;
  const description = options?.description ?? "";
  const argsSchema = options?.args ?? null;
  const allowedOutlets = options?.allowedOutlets ?? null;
  const deniedOutlets = options?.deniedOutlets ?? null;

  // === Decoration-time validation ===
  // All validation happens here (not at render time) for fail-fast behavior.

  // Validate block name format (supports namespaced names)
  if (!VALID_NAMESPACED_BLOCK_PATTERN.test(name)) {
    raiseBlockError(
      `Block name "${name}" is invalid. ` +
        `Valid formats: "block-name" (core), "plugin:block-name" (plugin), ` +
        `"theme:namespace:block-name" (theme).`
    );
  }

  // Parse name to extract components (type, namespace, shortName)
  const parsed = parseBlockName(name);
  if (!parsed) {
    // This shouldn't happen if VALID_NAMESPACED_BLOCK_PATTERN passed, but be defensive
    raiseBlockError(`Block name "${name}" could not be parsed.`);
  }

  // Validate arg schema structure and types
  validateArgsSchema(argsSchema, name);

  // Validate outlet patterns are valid picomatch syntax (arrays of strings)
  validateOutletPatterns(allowedOutlets, name, "allowedOutlets");
  validateOutletPatterns(deniedOutlets, name, "deniedOutlets");

  // Detect conflicts between allowed and denied patterns.
  // This prevents configurations where a block is both allowed AND denied
  // in the same outlet, which would be confusing and likely a mistake.
  const conflict = detectPatternConflicts(allowedOutlets, deniedOutlets);
  if (conflict.conflict) {
    raiseBlockError(
      `Block "${name}": outlet "${conflict.details.outlet}" matches both ` +
        `allowedOutlets pattern "${conflict.details.allowed}" and ` +
        `deniedOutlets pattern "${conflict.details.denied}".`
    );
  }

  // Warn if patterns don't match any known outlet (possible typos).
  // Namespaced patterns (containing `:`) are skipped since they target
  // plugin/theme-defined outlets not in the core registry.
  warnUnknownOutletPatterns(allowedOutlets, name, "allowedOutlets");
  warnUnknownOutletPatterns(deniedOutlets, name, "deniedOutlets");

  return function (target) {
    if (!(target.prototype instanceof Component)) {
      raiseBlockError("@block target must be a Glimmer component class");
      return target; // Return original in production to avoid crash
    }

    return class extends target {
      /** Full namespaced block name (e.g., "theme:tactile:hero-banner") */
      static blockName = name;

      /** Short block name without namespace (e.g., "hero-banner") */
      static blockShortName = parsed.name;

      /** Namespace portion of the name, or null for core blocks */
      static blockNamespace = parsed.namespace;

      /** Block type: "core", "plugin", or "theme" */
      static blockType = parsed.type;

      /**
       * Block metadata including description, container status, args schema,
       * and outlet restrictions. Used for introspection, documentation, and
       * runtime validation.
       *
       * @type {{
       *   description: string,
       *   container: boolean,
       *   args: Object|null,
       *   allowedOutlets: ReadonlyArray<string>|null,
       *   deniedOutlets: ReadonlyArray<string>|null
       * }}
       */
      static blockMetadata = Object.freeze({
        description,
        container: isContainer,
        args: argsSchema ? Object.freeze(argsSchema) : null,
        // Freeze metadata and arrays to prevent runtime mutations.
        // Spread into new arrays before freezing to avoid freezing caller's arrays.
        allowedOutlets: allowedOutlets
          ? Object.freeze([...allowedOutlets])
          : null,
        deniedOutlets: deniedOutlets ? Object.freeze([...deniedOutlets]) : null,
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
        const isLoggingEnabled = isBlockLoggingEnabled();
        // Build base hierarchy path for this container
        // (e.g., "outlet-name" for root, "outlet-name/parent-block" for nested)
        const baseHierarchy = this.isRoot
          ? this.outletName
          : this.args._hierarchy;
        const result = [];

        // Track container counts for indexing (e.g., group[0], group[1])
        const containerCounts = new Map();

        for (const blockConfig of rawChildren) {
          // Resolve block reference (string name or class)
          const resolvedBlock = this.#resolveBlockSync(blockConfig.block);

          // If block couldn't be resolved (unresolved factory), skip it
          // Async resolution has been triggered and block will appear on next render
          if (!resolvedBlock) {
            continue;
          }

          const blockName = resolvedBlock.blockName || "unknown";
          const isChildContainer =
            resolvedBlock[__BLOCK_CONTAINER_FLAG] ?? false;
          let conditionsPassed = true;

          // For containers, build their full path (used for their children's hierarchy)
          // e.g., "homepage-blocks/group[0]"
          let containerPath;
          if (isChildContainer) {
            const count = containerCounts.get(blockName) ?? 0;
            containerCounts.set(blockName, count + 1);
            containerPath = `${baseHierarchy}/${blockName}[${count}]`;
          }

          // Evaluate conditions if present
          if (blockConfig.conditions) {
            if (isLoggingEnabled) {
              blockDebugLogger.startGroup(blockName, baseHierarchy);
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
            // Pass baseHierarchy for debug display (where block is rendered)
            // Pass containerPath for container's children hierarchy
            // Use resolved block class instead of original config.block
            result.push(
              this.#createChildBlock(
                { ...blockConfig, block: resolvedBlock },
                owner,
                {
                  displayHierarchy: baseHierarchy,
                  containerPath,
                  conditions: blockConfig.conditions,
                }
              )
            );
          } else if (getBlockDebugCallback()) {
            // Block failed conditions - show ghost if debug overlay is enabled
            const ghostData = getBlockDebugCallback()(
              {
                name: blockName,
                Component: null,
                args: blockConfig.args,
                conditions: blockConfig.conditions,
                conditionsPassed: false,
              },
              { outletName: baseHierarchy }
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
       * @param {string} [debugContext.displayHierarchy] - Where the block is rendered (for tooltip display)
       * @param {string} [debugContext.containerPath] - Container's full path (for children's _hierarchy)
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
        // Pass containerPath so nested containers know their full path for debug logging.
        const blockArgs = isChildContainer
          ? this.#buildBlockArgs(
              argsWithDefaults,
              nestedChildren,
              debugContext.containerPath,
              { classNames }
            )
          : this.#buildBlockArgs(
              argsWithDefaults,
              nestedChildren,
              debugContext.displayHierarchy
            );

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
        const debugCallback = getBlockDebugCallback();
        if (debugCallback) {
          const debugResult = debugCallback(
            {
              name: ComponentClass.blockName,
              Component: wrappedComponent,
              args: argsWithDefaults,
              conditions: debugContext.conditions,
              conditionsPassed: true,
            },
            { outletName: debugContext.displayHierarchy }
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
       * @param {string} hierarchy - The hierarchy path for this child block
       * @param {Object} [extra] - Additional properties to include (e.g., { classNames })
       * @returns {Object} The complete args object for the child block
       */
      #buildBlockArgs(args, children, hierarchy, extra = {}) {
        return {
          ...args,
          children,
          _hierarchy: hierarchy, // Pass hierarchy to children for debug logging
          $block$: __BLOCK_CONTAINER_FLAG, // Pass the secret symbol to authorize child block instantiation
          ...extra,
        };
      }

      /**
       * Synchronously resolves a block reference to a BlockClass.
       *
       * - If given a class, returns it directly.
       * - If given a string and the block is resolved, returns the class.
       * - If given a string and the block is an unresolved factory, triggers
       *   async resolution and returns null (block will appear on next render).
       *
       * @param {string | typeof Component} blockRef - Block name or class.
       * @returns {typeof Component | null} Resolved block class, or null if pending.
       */
      #resolveBlockSync(blockRef) {
        // Class reference - return directly
        if (typeof blockRef !== "string") {
          return blockRef;
        }

        // String reference - check if registered
        if (!blockRegistry.has(blockRef)) {
          // Block not registered - this is an error, but validation should have caught it
          // eslint-disable-next-line no-console
          console.error(`[Blocks] Block "${blockRef}" is not registered.`);
          return null;
        }

        const entry = blockRegistry.get(blockRef);

        // If already resolved (not a factory), return the class
        if (!isBlockFactory(entry)) {
          return entry;
        }

        // Factory needs async resolution - trigger it and return null for now
        // The block will appear on the next render after resolution completes
        if (!DEBUG) {
          // Only in production - in dev, factories are already resolved during validation
          resolveBlock(blockRef).catch((error) => {
            // eslint-disable-next-line no-console
            console.error(
              `[Blocks] Failed to resolve block "${blockRef}":`,
              error
            );
          });
        }

        return null;
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
 * Note: This function is exported for validation but should not be used
 * to bypass block security. It only returns a boolean, not the symbol itself.
 *
 * @param {Function} component - The component to check
 * @returns {boolean} True if the component is registered as a container block, false otherwise
 */
export function isContainerBlock(component) {
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
  // Get blocks service for condition validation if owner is provided
  const blocksService = owner?.lookup("service:blocks");

  // Check for duplicate registration before anything else
  if (blockConfigs.has(outletName)) {
    raiseBlockError(
      `Block outlet "${outletName}" already has a configuration registered.`
    );
  }

  // Lock the block registry immediately.
  // This prevents themes/plugins from registering new blocks after
  // the first renderBlocks() call.
  const { _lockBlockRegistry } = require("discourse/lib/blocks/registration");
  _lockBlockRegistry();

  // Start async validation. In dev mode, this eagerly resolves all factories
  // for early error detection. In prod, it defers factory resolution.
  const validationPromise = validateConfig(
    config,
    outletName,
    blocksService,
    isBlock,
    isContainerBlock
  );

  // Handle validation errors
  validationPromise.catch((error) => {
    // In dev mode, re-throw to surface errors prominently
    if (DEBUG) {
      // Use setTimeout to throw outside the promise chain for better stack traces
      setTimeout(() => {
        throw error;
      }, 0);
    }
    // In prod, errors are handled by raiseBlockError (dispatches event)
  });

  // Store config with validation promise for potential future use
  blockConfigs.set(outletName, { children: config, validationPromise });
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
    return isOutletBoundaryEnabled();
  }

  /**
   * The component to render for outlet boundary debug info.
   * Set by dev-tools via _setBlockOutletInfoComponent.
   *
   * @returns {typeof Component|null}
   */
  get OutletInfoComponent() {
    return getOutletInfoComponent();
  }

  /**
   * Number of blocks registered for this outlet.
   * Used in debug overlay to show block count.
   *
   * @returns {number}
   */
  get blockCount() {
    return this.children?.length ?? 0;
  }

  <template>
    {{! Yield to :before block with hasConfig boolean for conditional rendering }}
    {{yield (hasConfig this.outletName) to="before"}}

    {{#if this.showOutletBoundary}}
      <div class="block-outlet-debug">
        {{#if this.OutletInfoComponent}}
          <this.OutletInfoComponent
            @outletName={{this.outletName}}
            @hasBlocks={{this.blockCount}}
            @blockCount={{this.blockCount}}
          />
        {{else}}
          <span class="block-outlet-debug__badge">{{icon "cubes"}}
            {{this.outletName}}
          </span>
        {{/if}}
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
