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
import { service } from "@ember/service";
import { TrackedAsyncData } from "ember-async-data";
import curryComponent from "ember-curry-component";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import dasherize from "discourse/helpers/dasherize";
import {
  validateArgsSchema,
  validateChildArgsSchema,
} from "discourse/lib/blocks/arg-validation";
import {
  buildContainerPath,
  createGhostBlock,
  handleOptionalMissingBlock,
  isOptionalMissing,
} from "discourse/lib/blocks/block-processing";
import { validateConfig } from "discourse/lib/blocks/config-validation";
import { validateConstraintsSchema } from "discourse/lib/blocks/constraint-validation";
import { DEBUG_CALLBACK, debugHooks } from "discourse/lib/blocks/debug-hooks";
import { captureCallSite, raiseBlockError } from "discourse/lib/blocks/error";
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
  isBlockRegistryFrozen,
  resolveBlockSync,
} from "discourse/lib/blocks/registration";
import { applyArgDefaults } from "discourse/lib/blocks/utils";
import { isRailsTesting, isTesting } from "discourse/lib/environment";
import { buildArgsWithDeprecations } from "discourse/lib/outlet-args";
import { BLOCK_OUTLETS } from "discourse/lib/registry/block-outlets";
import { formatWithSuggestion } from "discourse/lib/string-similarity";

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

/**
 * Returns the internal block configs map for testing.
 * Allows tests to access validation promises to verify error handling.
 *
 * USE ONLY FOR TESTING PURPOSES.
 *
 * @returns {Map<string, {validatedConfig: Promise}>} The block configs map.
 */
export function _getBlockConfigs() {
  if (DEBUG) {
    return blockConfigs;
  }
  return new Map();
}

/**
 * Valid config keys for the @block decorator options.
 * @constant {ReadonlyArray<string>}
 */
const VALID_BLOCK_OPTIONS = Object.freeze([
  "container",
  "description",
  "args",
  "childArgs",
  "constraints",
  "validate",
  "allowedOutlets",
  "deniedOutlets",
]);

/*
 * Security Symbols
 *
 * IMPORTANT: These symbols MUST NOT be exported.
 * DO NOT REFACTOR TO EXTRACT THESE SYMBOLS INTO ANOTHER FILE
 *
 * These secret symbols form the core of the block security model. They allow
 * the system to verify that:
 * 1. A component was decorated with @block (has __BLOCK_FLAG)
 * 2. A component is authorized to contain children (has __BLOCK_CONTAINER_FLAG)
 * 3. A block is being rendered in an authorized context (via $block$ arg)
 *
 * By keeping these symbols private, we prevent external code from spoofing
 * block authorization or bypassing validation.
 */
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
  // === Decoration-time validation ===
  // All validation happens here (not at render time) for fail-fast behavior.

  // Validate no unknown options keys (catches typos like "containers" or "allowedOutlet")
  if (options && typeof options === "object") {
    const unknownKeys = Object.keys(options).filter(
      (key) => !VALID_BLOCK_OPTIONS.includes(key)
    );
    if (unknownKeys.length > 0) {
      const suggestions = unknownKeys
        .map((key) => formatWithSuggestion(key, VALID_BLOCK_OPTIONS))
        .join(", ");
      raiseBlockError(
        `@block("${name}"): unknown option(s): ${suggestions}. ` +
          `Valid options are: ${VALID_BLOCK_OPTIONS.join(", ")}.`
      );
    }
  }

  // Extract all options with defaults
  const isContainer = options?.container ?? false;
  const description = options?.description ?? "";
  const argsSchema = options?.args ?? null;
  const childArgsSchema = options?.childArgs ?? null;
  const constraints = options?.constraints ?? null;
  const validateFn = options?.validate ?? null;
  const allowedOutlets = options?.allowedOutlets ?? null;
  const deniedOutlets = options?.deniedOutlets ?? null;

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

  // Validate childArgs is only allowed on container blocks
  if (childArgsSchema && !isContainer) {
    raiseBlockError(
      `Block "${name}": "childArgs" is only valid for container blocks (container: true).`
    );
  }

  // Validate childArgs schema structure and types (includes unique property)
  validateChildArgsSchema(childArgsSchema, name);

  // Validate constraints schema (references to args, incompatible constraints, vacuous constraints)
  validateConstraintsSchema(constraints, argsSchema, name);

  // Validate that validate is a function if provided
  if (validateFn !== null && typeof validateFn !== "function") {
    raiseBlockError(
      `Block "${name}": "validate" must be a function, got ${typeof validateFn}.`
    );
  }

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

  // Create metadata object once (returned by getter)
  const metadata = Object.freeze({
    description,
    container: isContainer,
    args: argsSchema ? Object.freeze(argsSchema) : null,
    childArgs: childArgsSchema ? Object.freeze(childArgsSchema) : null,
    constraints: constraints ? Object.freeze(constraints) : null,
    validate: validateFn,
    allowedOutlets: allowedOutlets ? Object.freeze([...allowedOutlets]) : null,
    deniedOutlets: deniedOutlets ? Object.freeze([...deniedOutlets]) : null,
  });

  return function (target) {
    if (!(target.prototype instanceof Component)) {
      raiseBlockError("@block target must be a Glimmer component class");
      return target; // Return original in production to avoid crash
    }

    return class extends target {
      /** Full namespaced block name (e.g., "theme:tactile:hero-banner") */
      static get blockName() {
        return name;
      }

      /** Short block name without namespace (e.g., "hero-banner") */
      static get blockShortName() {
        return parsed.name;
      }

      /** Namespace portion of the name, or null for core blocks */
      static get blockNamespace() {
        return parsed.namespace;
      }

      /** Block type: "core", "plugin", or "theme" */
      static get blockType() {
        return parsed.type;
      }

      /**
       * Block metadata including description, container status, args schema,
       * childArgs schema, constraints, validate function, and outlet restrictions.
       * Used for introspection, documentation, and runtime validation.
       *
       * @type {{
       *   description: string,
       *   container: boolean,
       *   args: Object|null,
       *   childArgs: Object|null,
       *   constraints: Object|null,
       *   validate: Function|null,
       *   allowedOutlets: ReadonlyArray<string>|null,
       *   deniedOutlets: ReadonlyArray<string>|null
       * }}
       */
      static get blockMetadata() {
        return metadata;
      }

      /**
       * Cache for curried child components in nested containers.
       *
       * Similar to BlockOutletRootContainer's cache, this prevents
       * unnecessary recreation of leaf block children during navigation.
       *
       * @type {Map<string, {ComponentClass: typeof Component, args: Object, result: Object}>}
       */
      #childComponentCache = new Map();

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
       * Gets or creates a curried child component, using the cache when possible.
       *
       * Only caches leaf blocks (blocks without children). Container blocks are
       * always recreated to ensure their children reflect current visibility.
       *
       * @param {Object} blockConfig - The block configuration.
       * @param {typeof Component} resolvedBlock - The resolved block component class.
       * @param {Object} debugContext - Debug context for the block.
       * @param {import("@ember/owner").default} owner - The application owner.
       * @returns {{Component: import("ember-curry-component").CurriedComponent, containerArgs: Object|undefined, key: string}}
       *   The cached or newly created component data.
       */
      #getOrCreateChildComponent(
        blockConfig,
        resolvedBlock,
        debugContext,
        owner
      ) {
        const { key } = debugContext;
        const cachedEntry = this.#childComponentCache.get(key);
        const hasChildren = blockConfig.children?.length > 0;

        // Only cache leaf blocks (no children)
        if (
          !hasChildren &&
          cachedEntry &&
          cachedEntry.ComponentClass === resolvedBlock &&
          shallowArgsEqual(cachedEntry.args, blockConfig.args)
        ) {
          return cachedEntry.result;
        }

        // Create new curried component
        const result = createChildBlock(
          { ...blockConfig, block: resolvedBlock },
          owner,
          debugContext
        );

        // Cache leaf blocks for future reuse
        if (!hasChildren) {
          this.#childComponentCache.set(key, {
            ComponentClass: resolvedBlock,
            args: blockConfig.args,
            result,
          });
        }

        return result;
      }

      /**
       * Processes and returns child blocks as renderable components.
       * Only container blocks have children. The children are curried components
       * with all necessary args pre-bound.
       *
       * For root blocks (BlockOutlet), this defers to the component's own children
       * getter which handles preprocessing. For nested containers, configs are
       * already pre-processed by the parent, so we just create components.
       *
       * Each child object contains:
       * - `Component`: The curried block component ready to render
       * - `containerArgs`: Values provided by the child config for the parent's
       *   `childArgs` schema (e.g., `{ name: "settings" }` for a tabs container).
       *   These are available to the parent but not passed to the child block itself.
       *
       * @returns {Array<{Component: import("ember-curry-component").CurriedComponent, containerArgs: Object|undefined}>|undefined}
       */
      @cached
      get children() {
        // set the tracking before any guard clause to ensure updating the options in the dev tools will track state
        const showGhosts = debugHooks.isVisualOverlayEnabled;

        // Non-containers have no children
        if (!isContainer) {
          return;
        }

        // Root blocks (BlockOutlet) override this getter to do full preprocessing.
        // Defer to the component's own implementation.
        if (this.isRoot) {
          return super.children;
        }

        // Nested containers: configs already pre-processed by parent
        const rawChildren = this.args.children;
        if (!rawChildren?.length) {
          return;
        }

        const owner = getOwner(this);
        const baseHierarchy = this.args._hierarchy;
        const outletArgs = this.args.outletArgs;
        // Logging already done during root preprocessing
        const isLoggingEnabled = false;

        // Configs already have __visible set by parent's preprocessing.
        // Just create components from them.
        const processedConfigs = rawChildren;

        const result = [];
        // Track container counts for indexing (e.g., group[0], group[1])
        const containerCounts = new Map();

        for (let i = 0; i < processedConfigs.length; i++) {
          const blockConfig = processedConfigs[i];
          // Resolve block reference (string name or class)
          const resolvedBlock = resolveBlockSync(blockConfig.block);

          // Handle optional missing block (block ref ended with `?` but not registered)
          if (isOptionalMissing(resolvedBlock)) {
            const key = `optional-missing:${resolvedBlock.name}:${i}`;
            const ghostData = handleOptionalMissingBlock({
              blockName: resolvedBlock.name,
              blockConfig,
              hierarchy: baseHierarchy,
              isLoggingEnabled,
              showGhosts,
              key,
            });
            if (ghostData) {
              result.push(ghostData);
            }
            continue;
          }

          // Skip unresolved blocks (pending factory resolution)
          if (!resolvedBlock) {
            continue;
          }

          const blockName = resolvedBlock.blockName || "unknown";
          const isChildContainer =
            resolvedBlock[__BLOCK_CONTAINER_FLAG] ?? false;

          // Generate stable unique key based on block name and position
          const key = `${blockName}:${i}`;

          // For containers, build their full path for children's hierarchy
          const containerPath = isChildContainer
            ? buildContainerPath(blockName, baseHierarchy, containerCounts)
            : undefined;

          // Render visible blocks
          if (blockConfig.__visible) {
            result.push(
              this.#getOrCreateChildComponent(
                blockConfig,
                resolvedBlock,
                {
                  displayHierarchy: baseHierarchy,
                  containerPath,
                  conditions: blockConfig.conditions,
                  outletArgs,
                  key,
                },
                owner
              )
            );
          } else if (showGhosts) {
            // Show ghost for invisible blocks in debug mode
            const ghostData = createGhostBlock({
              blockName,
              blockConfig,
              hierarchy: baseHierarchy,
              containerPath,
              isContainer: isChildContainer,
              owner,
              outletArgs,
              isLoggingEnabled,
              resolveBlockFn: resolveBlockSync,
              key,
            });
            if (ghostData) {
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
    };
  };
}

/**
 * Performs a shallow comparison of two args objects.
 *
 * Compares top-level values using strict equality (===). Does not perform
 * deep comparison of nested objects. Used to determine if cached curried
 * components can be reused.
 *
 * @param {Object|null|undefined} a - First args object.
 * @param {Object|null|undefined} b - Second args object.
 * @returns {boolean} True if the args are shallowly equal, false otherwise.
 */
function shallowArgsEqual(a, b) {
  if (a === b) {
    return true;
  }
  if (a == null || b == null) {
    return false;
  }
  const keysA = Object.keys(a);
  const keysB = Object.keys(b);
  if (keysA.length !== keysB.length) {
    return false;
  }
  return keysA.every((key) => a[key] === b[key]);
}

/**
 * Builds the args object to pass to a child block.
 *
 * Uses getter-based properties for system args (`children`, `_hierarchy`,
 * `outletArgs`) to support per-argument reactivity with `curryComponent`.
 * This allows the curried component to remain stable while individual args
 * can update reactively.
 *
 * @param {Object} args - User-provided args from block config.
 * @param {Array<Object>|undefined} children - Nested children configs.
 * @param {string} hierarchy - The hierarchy path for this child block.
 * @param {Object} outletArgs - Outlet args to pass through to the block.
 * @param {Object} [extra] - Additional properties to include (e.g., { classNames }).
 * @returns {Object} The complete args object for the child block.
 */
function buildBlockArgs(args, children, hierarchy, outletArgs, extra = {}) {
  const blockArgs = {
    ...args,
    $block$: __BLOCK_CONTAINER_FLAG, // Pass the secret symbol to authorize child block instantiation
    ...extra,
  };

  // Define reactive getters for system args. This allows curryComponent to
  // maintain a stable component reference while these values can update.
  Object.defineProperties(blockArgs, {
    children: {
      get() {
        return children;
      },
      enumerable: true,
    },
    _hierarchy: {
      get() {
        return hierarchy;
      },
      enumerable: true,
    },
    outletArgs: {
      get() {
        return outletArgs;
      },
      enumerable: true,
    },
  });

  return blockArgs;
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
 * @param {Object} [debugContext.outletArgs] - Outlet args for debug display
 * @param {string} [debugContext.key] - Stable unique key for this block
 * @returns {{Component: import("ember-curry-component").CurriedComponent, containerArgs: Object|undefined, key: string}}
 *   An object containing the curried block component, any containerArgs
 *   provided in the block config, and a stable unique key for list rendering.
 *   The containerArgs are values required by the parent container's childArgs
 *   schema, accessible to the parent but not to the child block itself.
 */
function createChildBlock(blockConfig, owner, debugContext = {}) {
  const {
    block: ComponentClass,
    args = {},
    containerArgs,
    classNames,
    children: nestedChildren,
  } = blockConfig;
  const isChildContainer = ComponentClass[__BLOCK_CONTAINER_FLAG];

  // Apply default values from metadata before building args
  const argsWithDefaults = applyArgDefaults(ComponentClass, args);

  // Container blocks receive classNames directly (they handle their own wrapper).
  // Non-container blocks get classNames passed to wrapBlockLayout instead.
  // Pass containerPath so nested containers know their full path for debug logging.
  const blockArgs = isChildContainer
    ? buildBlockArgs(
        argsWithDefaults,
        nestedChildren,
        debugContext.containerPath,
        debugContext.outletArgs,
        { classNames }
      )
    : buildBlockArgs(
        argsWithDefaults,
        nestedChildren,
        debugContext.displayHierarchy,
        debugContext.outletArgs
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
  const debugCallback = debugHooks.getCallback(DEBUG_CALLBACK.BLOCK_DEBUG);
  if (debugCallback) {
    const debugResult = debugCallback(
      {
        name: ComponentClass.blockName,
        Component: wrappedComponent,
        args: argsWithDefaults,
        containerArgs,
        conditions: debugContext.conditions,
        conditionsPassed: true,
      },
      {
        outletName: debugContext.displayHierarchy,
        outletArgs: debugContext.outletArgs,
      }
    );
    if (debugResult?.Component) {
      wrappedComponent = debugResult.Component;
    }
  }

  return { Component: wrappedComponent, containerArgs, key: debugContext.key };
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
export function renderBlocks(outletName, config, owner, callSiteError = null) {
  // Use provided call site error, or capture one here as fallback.
  // When called via api.renderBlocks(), the call site is captured there
  // to exclude the PluginApi wrapper from the stack trace.
  if (!callSiteError) {
    callSiteError = captureCallSite(renderBlocks);
  }

  // === Synchronous validation for outlet-level checks ===
  // These don't depend on block resolution and can fail fast.

  // Check for duplicate registration before anything else
  if (blockConfigs.has(outletName)) {
    raiseBlockError(
      `Block outlet "${outletName}" already has a configuration registered.`
    );
  }

  // Validate outlet name is known
  if (!BLOCK_OUTLETS.includes(outletName)) {
    raiseBlockError(`Unknown block outlet: ${outletName}`);
  }

  // Verify registries are frozen before allowing renderBlocks().
  // This ensures all blocks and conditions are registered before any layout configuration.
  // MUST happen before service lookup to avoid instantiating service with empty registries.
  if (!isBlockRegistryFrozen()) {
    raiseBlockError(
      `api.renderBlocks() was called before the block registry was frozen. ` +
        `Move your code to an initializer that runs after "freeze-block-registry". ` +
        `Outlet: "${outletName}"`
    );
  }

  // Get blocks service for condition validation (safe now that registries are frozen)
  const blocksService = owner?.lookup("service:blocks");

  // All block validation is async (handles both class refs and string refs).
  // In dev mode, this eagerly resolves all factories for early error detection.
  // In prod, it defers factory resolution to render time.
  //
  // Validation errors are reported via raiseBlockError() which:
  // - In DEBUG: throws (surfacing as unhandled rejection in console)
  // - In prod: dispatches a 'block-error' event
  //
  // The promise is returned so tests can await and catch errors.
  const validatedConfig = validateConfig(
    config,
    outletName,
    blocksService,
    isBlock,
    isContainerBlock,
    "", // parentPath - empty so paths start with array index like [0]
    callSiteError // Error object for source-mapped call site
  ).then(() => config);

  // Store config with validation promise for potential future use
  blockConfigs.set(outletName, { validatedConfig });

  return validatedConfig;
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

  get validatedConfig() {
    return blockConfigs.get(this.#name)?.validatedConfig;
  }

  /**
   * Processes block configurations and returns renderable components.
   *
   * This is the root-level implementation that:
   * 1. Gets raw configs from the block registry
   * 2. Preprocesses them to evaluate conditions and compute visibility
   * 3. Creates renderable components from visible blocks
   * 4. Creates ghost components for invisible blocks (in debug mode)
   *
   * The decorator's `children` getter defers to this for root blocks,
   * while nested containers use their own simplified logic since
   * their configs are already preprocessed by their parent.
   *
   * Each child object contains:
   * - `Component`: The curried block component ready to render
   * - `containerArgs`: Values provided by the child config for the parent's
   *   `childArgs` schema (accessible to parent, not the child block itself)
   *
   * @returns {Array<{Component: import("ember-curry-component").CurriedComponent, containerArgs: Object|undefined}>|undefined}
   */
  // @cached
  get children() {
    // we need to track the state outside the promise contexts to force the children to be rendered when
    // the user enables the debugging
    const showGhosts = debugHooks.isVisualOverlayEnabled;
    const isLoggingEnabled = debugHooks.isBlockLoggingEnabled;

    if (!this.validatedConfig) {
      return;
    }

    /* Block configs are validated asynchronously. TrackedAsyncData lets us wait
       for validation to complete before rendering blocks, while also exposing
       any validation errors to the debug overlay.

       Note: We intentionally do NOT evaluate conditions here. Condition evaluation
       happens in BlockOutletRootContainer.processedChildren so that service reads
       (router.currentURL, discovery.category, etc.) are tracked by Ember's
       autotracking system. If we evaluated conditions inside this promise, route
       changes would not trigger re-evaluation. */
    const promiseWithLogging = this.validatedConfig
      .then((rawChildren) => {
        if (!rawChildren.length) {
          return;
        }

        // Return raw configs and metadata - BlockOutletRootContainer will handle
        // condition evaluation and component creation in a tracked context
        return { rawChildren, showGhosts, isLoggingEnabled };
      })
      .catch((error) => {
        // Note on test failures:
        // - Validation errors (from validateConfig): Already fail tests as
        //   unhandled promise rejections before this handler runs.
        // - Preprocessing errors (from .then block above): Need setTimeout to
        //   escape TrackedAsyncData's error handling and surface as test failures.
        if (isTesting() || isRailsTesting()) {
          setTimeout(() => {
            throw error;
          }, 0);
        }

        // Notify admins via the client error handler
        // This also logs the error in the console automatically
        document.dispatchEvent(
          new CustomEvent("discourse-error", {
            detail: { messageKey: "broken_block_alert", error },
          })
        );

        throw error;
      });

    return new TrackedAsyncData(promiseWithLogging);
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
    return debugHooks.isOutletBoundaryEnabled;
  }

  /**
   * The component to render for outlet boundary debug info.
   * Set by dev-tools via _setBlockOutletInfoComponent.
   *
   * @returns {typeof Component|null}
   */
  get OutletInfoComponent() {
    return debugHooks.getCallback(DEBUG_CALLBACK.OUTLET_INFO_COMPONENT);
  }

  /**
   * Number of blocks registered for this outlet.
   * Used in debug overlay to show block count.
   *
   * @returns {number}
   */
  get blockCount() {
    if (!this.children?.isResolved) {
      return 0;
    }
    return this.children.value?.length ?? 0;
  }

  /**
   * Validation error if the block config failed validation.
   * Only accessible when the validation promise has rejected.
   *
   * @returns {Error|null}
   */
  get validationError() {
    if (!this.children?.isRejected) {
      return null;
    }
    return this.children.error;
  }

  /**
   * Combines `@outletArgs` with `@deprecatedArgs` for lazy evaluation.
   *
   * Outlet args are values passed from the parent template to blocks rendered
   * in this outlet. They are separate from block config args and accessed via
   * `@outletArgs` in block components.
   *
   * Deprecated args trigger a deprecation warning when accessed, helping
   * migrate consumers away from renamed or removed outlet args.
   *
   * @returns {Object} Combined args object with lazy property getters
   */
  @cached
  get outletArgsWithDeprecations() {
    if (!this.args.deprecatedArgs) {
      return this.args.outletArgs || {};
    }
    return buildArgsWithDeprecations(
      this.args.outletArgs || {},
      this.args.deprecatedArgs,
      { outletName: this.#name }
    );
  }

  <template>
    {{! Yield to :before block with hasConfig boolean for conditional rendering }}
    {{yield (hasConfig this.outletName) to="before"}}

    {{#if this.showOutletBoundary}}
      <div
        class={{concatClass
          "block-outlet-debug"
          (if this.children.isRejected "--validation-failed")
        }}
      >
        {{#if this.OutletInfoComponent}}
          <this.OutletInfoComponent
            @outletName={{this.outletName}}
            @hasBlocks={{this.blockCount}}
            @blockCount={{this.blockCount}}
            @outletArgs={{this.outletArgsWithDeprecations}}
            @error={{this.validationError}}
          />
        {{else}}
          <span class="block-outlet-debug__badge">{{icon "cubes"}}
            {{this.outletName}}
          </span>
        {{/if}}
        {{#if this.children}}
          {{#if this.children.isResolved}}
            <BlockOutletRootContainer
              @outletName={{this.outletName}}
              @outletArgs={{this.outletArgsWithDeprecations}}
              @rawChildren={{this.children.value.rawChildren}}
              @showGhosts={{this.children.value.showGhosts}}
              @isLoggingEnabled={{this.children.value.isLoggingEnabled}}
            />
          {{/if}}
        {{/if}}
      </div>
    {{else if this.children}}
      {{#if this.children.isResolved}}
        <BlockOutletRootContainer
          @outletName={{this.outletName}}
          @outletArgs={{this.outletArgsWithDeprecations}}
          @rawChildren={{this.children.value.rawChildren}}
          @showGhosts={{this.children.value.showGhosts}}
          @isLoggingEnabled={{this.children.value.isLoggingEnabled}}
        />
      {{/if}}
    {{/if}}

    {{! Yield to :after block with hasConfig boolean for conditional rendering }}
    {{yield (hasConfig this.outletName) to="after"}}
  </template>
}

/**
 * Root container component that processes and renders block children.
 *
 * This component handles condition evaluation and component creation in a
 * tracked getter context. This is intentional - by evaluating conditions
 * synchronously in `processedChildren`, Ember's autotracking system can
 * establish dependencies on services like `router` and `discovery`. When
 * routes change, this getter re-runs and blocks are re-evaluated.
 *
 * If condition evaluation happened in the async promise chain (as it did
 * previously), service reads would not be tracked and route navigation
 * would not trigger re-evaluation.
 */
class BlockOutletRootContainer extends Component {
  @service blocks;

  /**
   * Cache for curried components, keyed by their stable block key.
   *
   * This cache prevents unnecessary component recreation during navigation.
   * Components are reused when their class and args haven't changed.
   *
   * @type {Map<string, {ComponentClass: typeof Component, args: Object, result: Object}>}
   */
  #componentCache = new Map();

  /**
   * Cleans up the component cache when the container is destroyed.
   */
  willDestroy() {
    super.willDestroy?.(...arguments);
    this.#componentCache.clear();
  }

  /**
   * Gets or creates a curried component, using the cache when possible.
   *
   * This method checks if a cached component can be reused by comparing:
   * 1. The component class (must be the same reference)
   * 2. The args object (shallow comparison of top-level values)
   *
   * If either has changed, a new curried component is created and cached.
   *
   * Container blocks with children are NOT cached because their children configs
   * may change between renders (e.g., visibility changes). Caching them would
   * result in stale children being displayed. Leaf blocks (no children) are
   * safe to cache since they have no nested content that could become stale.
   *
   * @param {Object} blockConfig - The block configuration.
   * @param {typeof Component} resolvedBlock - The resolved block component class.
   * @param {Object} debugContext - Debug context for the block.
   * @param {string} debugContext.key - Stable unique key for cache lookup.
   * @param {import("@ember/owner").default} owner - The application owner.
   * @returns {{Component: import("ember-curry-component").CurriedComponent, containerArgs: Object|undefined, key: string}}
   *   The cached or newly created component data.
   */
  #getOrCreateCurriedComponent(
    blockConfig,
    resolvedBlock,
    debugContext,
    owner
  ) {
    const { key } = debugContext;
    const cachedEntry = this.#componentCache.get(key);
    const hasChildren = blockConfig.children?.length > 0;

    // Only cache leaf blocks (no children). Container blocks are always recreated
    // to ensure their children reflect current visibility state.
    if (
      !hasChildren &&
      cachedEntry &&
      cachedEntry.ComponentClass === resolvedBlock &&
      shallowArgsEqual(cachedEntry.args, blockConfig.args)
    ) {
      return cachedEntry.result;
    }

    // Create new curried component
    const result = createChildBlock(
      { ...blockConfig, block: resolvedBlock },
      owner,
      debugContext
    );

    // Cache leaf blocks for future reuse
    if (!hasChildren) {
      this.#componentCache.set(key, {
        ComponentClass: resolvedBlock,
        args: blockConfig.args,
        result,
      });
    }

    return result;
  }

  /**
   * Processes raw block configs and creates renderable child components.
   *
   * This getter is the key to reactive condition evaluation. By accessing
   * services like `router` and `discovery` during condition evaluation here
   * (synchronously in a tracked getter), Ember establishes tracking
   * dependencies. Route changes trigger this getter to re-run.
   *
   * @returns {Array<{Component: import("ember-curry-component").CurriedComponent, containerArgs: Object|undefined}>}
   */
  @cached
  get processedChildren() {
    const {
      rawChildren,
      showGhosts,
      isLoggingEnabled,
      outletName,
      outletArgs,
    } = this.args;

    if (!rawChildren?.length) {
      return [];
    }

    const owner = getOwner(this);
    const baseHierarchy = outletName;

    // Step 1: Evaluate conditions - THIS IS NOW TRACKED!
    // When blocksService.evaluate() reads router.currentURL or discovery.category,
    // Ember establishes a dependency. Route changes trigger re-evaluation.
    const processedConfigs = this.#preprocessConfigs(
      rawChildren,
      outletArgs,
      this.blocks,
      showGhosts,
      isLoggingEnabled,
      baseHierarchy
    );

    // Step 2: Create components from processed configs
    const result = [];
    const containerCounts = new Map();

    for (let i = 0; i < processedConfigs.length; i++) {
      const blockConfig = processedConfigs[i];
      const resolvedBlock = resolveBlockSync(blockConfig.block);

      // Handle optional missing block (block ref ended with `?` but not registered)
      if (isOptionalMissing(resolvedBlock)) {
        // Generate key for optional missing blocks
        const key = `optional-missing:${resolvedBlock.name}:${i}`;
        const ghostData = handleOptionalMissingBlock({
          blockName: resolvedBlock.name,
          blockConfig,
          hierarchy: baseHierarchy,
          isLoggingEnabled,
          showGhosts,
          key,
        });
        if (ghostData) {
          result.push(ghostData);
        }
        continue;
      }

      // If block couldn't be resolved (unresolved factory), skip it
      if (!resolvedBlock) {
        continue;
      }

      const blockName = resolvedBlock.blockName || "unknown";
      const isChildContainer = resolvedBlock[__BLOCK_CONTAINER_FLAG] ?? false;

      // Generate stable unique key based on block name and position
      const key = `${blockName}:${i}`;

      // For containers, build their full path (used for their children's hierarchy)
      const containerPath = isChildContainer
        ? buildContainerPath(blockName, baseHierarchy, containerCounts)
        : undefined;

      // Check pre-computed visibility from preprocessing step
      if (blockConfig.__visible) {
        result.push(
          this.#getOrCreateCurriedComponent(
            blockConfig,
            resolvedBlock,
            {
              displayHierarchy: baseHierarchy,
              containerPath,
              conditions: blockConfig.conditions,
              outletArgs,
              key,
            },
            owner
          )
        );
      } else if (showGhosts) {
        // Create ghost for invisible block
        const ghostData = createGhostBlock({
          blockName,
          blockConfig,
          hierarchy: baseHierarchy,
          containerPath,
          isContainer: isChildContainer,
          owner,
          outletArgs,
          isLoggingEnabled,
          resolveBlockFn: resolveBlockSync,
          key,
        });

        if (ghostData) {
          result.push(ghostData);
        }
      }
    }

    return result;
  }

  /**
   * Pre-processes block configurations to compute visibility for all blocks.
   *
   * This method evaluates conditions for all blocks in the tree and adds
   * visibility metadata to each config:
   * - `__visible`: Whether the block should be rendered
   * - `__failureReason`: Why the block is hidden (debug mode only)
   *
   * Container blocks have an implicit condition: they must have at least
   * one visible child. This is evaluated bottom-up (children first).
   *
   * @param {Array<Object>} configs - Array of block configurations to process.
   * @param {Object} outletArgs - Outlet arguments for condition evaluation.
   * @param {Object} blocksService - Blocks service for condition evaluation.
   * @param {boolean} showGhosts - If true, keep all blocks for ghost rendering.
   * @param {boolean} isLoggingEnabled - If true, log condition evaluation.
   * @param {string} baseHierarchy - Base hierarchy path for logging.
   * @returns {Array<Object>} Processed configs with visibility metadata.
   */
  #preprocessConfigs(
    configs,
    outletArgs,
    blocksService,
    showGhosts,
    isLoggingEnabled,
    baseHierarchy
  ) {
    const result = [];

    for (const config of configs) {
      // Clone config to avoid mutating the original in the registry
      const configClone = { ...config };

      // Resolve block reference
      const resolvedBlock = resolveBlockSync(configClone.block);

      // Skip unresolved blocks (optional missing or pending factory resolution)
      if (!resolvedBlock || isOptionalMissing(resolvedBlock)) {
        // Keep the config for ghost handling in the main loop
        if (showGhosts || isOptionalMissing(resolvedBlock)) {
          result.push(configClone);
        }
        continue;
      }

      const blockName = resolvedBlock.blockName || "unknown";
      const isChildContainer = resolvedBlock[__BLOCK_CONTAINER_FLAG] ?? false;

      // Evaluate this block's own conditions
      let conditionsPassed = true;
      if (configClone.conditions) {
        if (isLoggingEnabled) {
          debugHooks.getCallback(DEBUG_CALLBACK.START_GROUP)?.(
            blockName,
            baseHierarchy
          );
        }

        // THIS IS THE KEY LINE - blocksService.evaluate() reads from router/discovery
        // services, and since we're in a tracked getter, Ember tracks these reads!
        conditionsPassed = blocksService.evaluate(configClone.conditions, {
          debug: isLoggingEnabled,
          outletArgs,
        });

        if (isLoggingEnabled) {
          debugHooks.getCallback(DEBUG_CALLBACK.END_GROUP)?.(conditionsPassed);
        }
      }

      // For containers: recursively process children first (bottom-up evaluation)
      // This determines which children are visible before we check if container has any
      let hasVisibleChildren = true; // Non-containers always "have" visible children
      if (isChildContainer && configClone.children?.length) {
        // Recursively preprocess children - this computes their visibility
        const processedChildren = this.#preprocessConfigs(
          configClone.children,
          outletArgs,
          blocksService,
          showGhosts,
          isLoggingEnabled,
          `${baseHierarchy}/${blockName}`
        );

        hasVisibleChildren = processedChildren.some((child) => child.__visible);

        // Update the cloned config's children with the processed result
        configClone.children = processedChildren;
      }

      // Final visibility: own conditions must pass AND (not container OR has visible children)
      // This implements the implicit "container must have visible children" condition
      const visible = conditionsPassed && hasVisibleChildren;
      configClone.__visible = visible;

      // In debug mode, record why the block is hidden for the ghost tooltip
      if (showGhosts && !visible) {
        configClone.__failureReason = !conditionsPassed
          ? "condition-failed"
          : "no-visible-children";
      }

      // In production mode, filter out invisible blocks
      // In debug mode, keep all blocks for ghost rendering
      if (visible || showGhosts) {
        result.push(configClone);
      }
    }

    return result;
  }

  <template>
    <div class={{@outletName}}>
      <div class="{{@outletName}}__container">
        <div class="{{@outletName}}__layout">
          {{#each this.processedChildren key="key" as |child|}}
            <child.Component
              @outletName={{@outletName}}
              @outletArgs={{@outletArgs}}
            />
          {{/each}}
        </div>
      </div>
    </div>
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
      (concat (dasherize @outletName) "__block")
      (concat "block-" (dasherize @name))
      @classNames
    }}
  >
    <@Component />
  </div>
</template>;
