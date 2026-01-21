// @ts-check
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
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { TrackedAsyncData } from "ember-async-data";
import curryComponent from "ember-curry-component";
/** @type {import("discourse/blocks/block-layout-wrapper.gjs")} */
import { wrapBlockLayout } from "discourse/blocks/block-layout-wrapper";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import {
  buildContainerPath,
  createGhostBlock,
  DEBUG_CALLBACK,
  debugHooks,
  handleOptionalMissingBlock,
  isOptionalMissing,
} from "discourse/lib/blocks/-internals/debug/block-processing";
import {
  captureCallSite,
  raiseBlockError,
} from "discourse/lib/blocks/-internals/error";
import {
  detectPatternConflicts,
  validateOutletPatterns,
  warnUnknownOutletPatterns,
} from "discourse/lib/blocks/-internals/matching/outlet-matcher";
import {
  parseBlockName,
  VALID_NAMESPACED_BLOCK_PATTERN,
} from "discourse/lib/blocks/-internals/patterns";
import {
  isBlockRegistryFrozen,
  resolveBlockSync,
} from "discourse/lib/blocks/-internals/registry/block";
import {
  applyArgDefaults,
  shallowArgsEqual,
} from "discourse/lib/blocks/-internals/utils";
import {
  validateArgsSchema,
  validateChildArgsSchema,
} from "discourse/lib/blocks/-internals/validation/block-args";
import { validateConstraintsSchema } from "discourse/lib/blocks/-internals/validation/constraints";
import { validateLayout } from "discourse/lib/blocks/-internals/validation/layout";
import { isRailsTesting, isTesting } from "discourse/lib/environment";
import { buildArgsWithDeprecations } from "discourse/lib/outlet-args";
import { BLOCK_OUTLETS } from "discourse/lib/registry/block-outlets";
import { formatWithSuggestion } from "discourse/lib/string-similarity";

/**
 * A block entry in a layout configuration.
 *
 * @typedef {Object} LayoutEntry
 * @property {typeof Component} block - The block component class (must use @block decorator).
 * @property {Object} [args] - Args to pass to the block component.
 * @property {string} [classNames] - Additional CSS classes for the block wrapper.
 * @property {Array<LayoutEntry>} [children] - Nested block entries (only for container blocks).
 * @property {Array<Object>|Object} [conditions] - Conditions that must pass for block to render.
 * @property {Object} [containerArgs] - Args passed from parent container's childArgs.
 */

/**
 * Maps outlet names to their registered outlet layouts.
 * Each outlet can have exactly one layout registered.
 *
 * @type {Map<string, {validatedLayout: Promise<Array<Object>>}>}
 */
const outletLayouts = new Map();

/**
 * Counter for generating stable entry keys.
 * Incremented each time a block entry is registered via `renderBlocks()`.
 *
 * @type {number}
 */
let nextEntryKey = 0;

/**
 * Recursively assigns stable keys to all block entries in a layout.
 *
 * Each entry receives a `__stableKey` property that remains constant across
 * renders. This is critical for Ember's `{{#each key=}}` to maintain DOM
 * identity when blocks are hidden/shown by conditions.
 *
 * Keys are assigned at registration time (in `renderBlocks()`) rather than
 * render time, ensuring they survive the shallow cloning in `#preprocessEntries`.
 *
 * @param {Array<Object>} entries - The block entries to process.
 */
function assignStableKeys(entries) {
  for (const entry of entries) {
    entry.__stableKey = nextEntryKey++;

    // Recursively assign keys to children
    if (entry.children?.length) {
      assignStableKeys(entry.children);
    }
  }
}

/**
 * Clears all registered outlet layouts.
 *
 * USE ONLY FOR TESTING PURPOSES.
 */
export function resetOutletLayoutsForTesting() {
  if (DEBUG) {
    outletLayouts.clear();
    nextEntryKey = 0;
  }
}

/**
 * Returns the internal outlet layouts map for testing.
 * Allows tests to access validation promises to verify error handling.
 *
 * USE ONLY FOR TESTING PURPOSES.
 *
 * @returns {Map<string, {validatedLayout: Promise}>} The outlet layouts map.
 */
export function _getOutletLayouts() {
  if (DEBUG) {
    return outletLayouts;
  }
  return new Map();
}

/**
 * Valid keys for the @block decorator options (block schema).
 * @constant {ReadonlyArray<string>}
 */
const VALID_BLOCK_OPTIONS = Object.freeze([
  "container",
  "containerClassNames",
  "description",
  "args",
  "childArgs",
  "constraints",
  "validate",
  "allowedOutlets",
  "deniedOutlets",
]);

/**
 * Validates the options object passed to the @block decorator.
 * Checks for unknown keys and provides suggestions for typos.
 *
 * @param {string} name - The block name (for error messages).
 * @param {Object} options - The options object to validate.
 */
function validateBlockOptions(name, options) {
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
}

/**
 * Validates and parses the block name.
 * Ensures the name follows the required format for core, plugin, or theme blocks.
 *
 * @param {string} name - The block name to validate.
 * @returns {import("discourse/lib/blocks/-internals/patterns").ParsedBlockName} Parsed name components.
 */
function validateAndParseBlockName(name) {
  if (!VALID_NAMESPACED_BLOCK_PATTERN.test(name)) {
    raiseBlockError(
      `Block name "${name}" is invalid. ` +
        `Valid formats: "block-name" (core), "plugin:block-name" (plugin), ` +
        `"theme:namespace:block-name" (theme).`
    );
  }

  const parsed = parseBlockName(name);
  if (!parsed) {
    // This shouldn't happen if VALID_NAMESPACED_BLOCK_PATTERN passed, but be defensive
    raiseBlockError(`Block name "${name}" could not be parsed.`);
  }

  return parsed;
}

/**
 * Validates outlet restriction patterns (allowedOutlets and deniedOutlets).
 * Checks for valid picomatch syntax and detects conflicts between patterns.
 *
 * @param {string} name - The block name (for error messages).
 * @param {string[]|null} allowedOutlets - Allowed outlet patterns.
 * @param {string[]|null} deniedOutlets - Denied outlet patterns.
 */
function validateOutletRestrictions(name, allowedOutlets, deniedOutlets) {
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
}

/**
 * Executes a function within a debug console group.
 * Ensures START_GROUP and END_GROUP callbacks are always paired.
 *
 * @param {string} blockName - The block name for the group label.
 * @param {string} hierarchy - The hierarchy path for context.
 * @param {boolean} isLoggingEnabled - Whether debug logging is active.
 * @param {() => boolean} fn - Function to execute that returns the condition result.
 * @returns {boolean} The result of the function execution.
 */
function withDebugGroup(blockName, hierarchy, isLoggingEnabled, fn) {
  if (!isLoggingEnabled) {
    return fn();
  }

  debugHooks.getCallback(DEBUG_CALLBACK.START_GROUP)?.(blockName, hierarchy);
  const result = fn();
  debugHooks.getCallback(DEBUG_CALLBACK.END_GROUP)?.(result);
  return result;
}

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
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
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
 * @param {Object.<string, ArgSchema>} [options.childArgs] - Schema for args passed to children
 *   of this container block. Only valid when container: true.
 *
 * @param {Object} [options.constraints] - Cross-arg validation constraints (atLeastOne, exactlyOne, allOrNone).
 *
 * @param {Function} [options.validate] - Custom validation function called after schema validation.
 *
 * @param {string|string[]|((args: Object) => string)} [options.containerClassNames] - Additional CSS
 *   classes for container block wrapper. Can be a string, array of strings, or function that receives
 *   args and returns a string. Only valid when container: true.
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
 * @property {RegExp} [pattern] - Regex pattern for string validation
 * @property {number} [minLength] - Minimum length for string or array
 * @property {number} [maxLength] - Maximum length for string or array
 * @property {number} [min] - Minimum value for number
 * @property {number} [max] - Maximum value for number
 * @property {boolean} [integer] - Whether number must be an integer
 * @property {Array} [enum] - Allowed values for the argument
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

  validateBlockOptions(name, options);
  const parsed = validateAndParseBlockName(name);

  // Extract all options with defaults
  const isContainer = options?.container ?? false;
  const containerClassNames = options?.containerClassNames ?? null;
  const description = options?.description ?? "";
  const argsSchema = options?.args ?? null;
  const childArgsSchema = options?.childArgs ?? null;
  const constraints = options?.constraints ?? null;
  const validateFn = options?.validate ?? null;
  const allowedOutlets = options?.allowedOutlets ?? null;
  const deniedOutlets = options?.deniedOutlets ?? null;

  // Validate arg schema structure and types
  validateArgsSchema(argsSchema, name);

  // Validate childArgs is only allowed on container blocks
  if (childArgsSchema && !isContainer) {
    raiseBlockError(
      `Block "${name}": "childArgs" is only valid for container blocks (container: true).`
    );
  }

  // Validate containerClassNames is only allowed on container blocks
  if (containerClassNames != null && !isContainer) {
    raiseBlockError(
      `Block "${name}": "containerClassNames" is only valid for container blocks (container: true).`
    );
  }

  // Validate containerClassNames type (string, array, or function)
  if (
    containerClassNames != null &&
    typeof containerClassNames !== "string" &&
    typeof containerClassNames !== "function" &&
    !Array.isArray(containerClassNames)
  ) {
    raiseBlockError(
      `Block "${name}": "containerClassNames" must be a string, array, or function.`
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

  // Validate outlet restriction patterns
  validateOutletRestrictions(name, allowedOutlets, deniedOutlets);

  // Create metadata object once (returned by getter)
  const metadata = Object.freeze({
    description,
    container: isContainer,
    containerClassNames,
    args: argsSchema ? Object.freeze(argsSchema) : null,
    childArgs: childArgsSchema ? Object.freeze(childArgsSchema) : null,
    constraints: constraints ? Object.freeze(constraints) : null,
    validate: validateFn,
    allowedOutlets: allowedOutlets ? Object.freeze([...allowedOutlets]) : null,
    deniedOutlets: deniedOutlets ? Object.freeze([...deniedOutlets]) : null,
  });

  // @ts-ignore - TS2322: Decorator return type mismatch (returns extended class)
  return function (target) {
    if (!(target.prototype instanceof Component)) {
      raiseBlockError("@block target must be a Glimmer component class");
      return target; // Return original in production to avoid crash
    }

    const DecoratedBlock = class extends target {
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
        // @ts-ignore - TS2556: Spread argument for parent class constructor
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
        // @ts-ignore - TS2339: __ROOT_BLOCK is dynamically added to constructor
        return this.constructor.__ROOT_BLOCK === __BLOCK_CONTAINER_FLAG;
      }

      /**
       * Returns the raw outlet layout. Only meaningful for root blocks.
       * For child blocks (non-root), this returns an empty array because their
       * layout is managed by their parent block.
       *
       * @returns {Array<Object>} The block entries, or an empty array for non-root blocks.
       */
      get layout() {
        // @ts-ignore - TS2339: layout getter added to root blocks (BlockOutlet)
        return this.isRoot ? super.layout : [];
      }

      /**
       * Processes and returns child blocks as renderable components.
       * Only container blocks have children. The children are curried components
       * with all necessary args pre-bound.
       *
       * For root blocks (BlockOutlet), this defers to the component's own children
       * getter which handles preprocessing. For nested containers, entries are
       * already pre-processed by the parent, so we just create components.
       *
       * Each child object contains:
       * - `Component`: The curried block component ready to render
       * - `containerArgs`: Values provided by the child entry for the parent's
       *   `childArgs` schema (e.g., `{ name: "settings" }` for a tabs container).
       *   These are available to the parent but not passed to the child block itself.
       *
       * @returns {Array<{Component: import("ember-curry-component").CurriedComponent, containerArgs: Object|undefined}>|undefined}
       */
      // @ts-ignore - TS1206: Decorators not valid in anonymous class expressions
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
          // @ts-ignore - TS2339: children getter added to root blocks (BlockOutlet)
          return super.children;
        }

        // Nested containers: entries already pre-processed by parent
        const rawChildren = this.args.children;
        if (!rawChildren?.length) {
          return;
        }

        // @ts-ignore - TS2322: ChildBlockResult type compatible with return type
        return processBlockEntries({
          entries: rawChildren,
          cache: this.#childComponentCache,
          owner: getOwner(this),
          baseHierarchy: this.args.__hierarchy,
          outletName: this.args.outletName,
          outletArgs: this.args.outletArgs,
          showGhosts,
          isLoggingEnabled: false,
        });
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

    // Define static getters (non-configurable to prevent reassignment).
    Object.defineProperties(DecoratedBlock, {
      blockName: {
        /**
         * The full namespaced block name (e.g., "theme:tactile:hero-banner").
         *
         * @type {() => string}
         */
        get: () => name,
        configurable: false,
      },
      blockShortName: {
        /**
         * The short block name without namespace (e.g., "hero-banner").
         *
         * @type {() => string}
         */
        get: () => parsed.name,
        configurable: false,
      },
      blockNamespace: {
        /**
         * The namespace portion of the name, or null for core blocks.
         *
         * @type {() => string|null}
         */
        get: () => parsed.namespace,
        configurable: false,
      },
      blockType: {
        /**
         * The block type indicating its source: "core", "plugin", or "theme".
         *
         * @type {() => "core"|"plugin"|"theme"}
         */
        get: () => parsed.type,
        configurable: false,
      },
      blockMetadata: {
        /**
         * Block configuration including description, container status, args schema,
         * childArgs schema, constraints, validate function, and outlet restrictions.
         *
         * @type {() => import("discourse/lib/blocks/-internals/registry/block").BlockMetadata}
         */
        get: () => metadata,
        configurable: false,
      },
    });

    return DecoratedBlock;
  };
}

/**
 * Gets or creates a curried component for a leaf block, using cache when possible.
 *
 * Only leaf blocks (blocks without children) are cached. Container blocks are
 * always recreated because their children's visibility may change between
 * renders, and caching would result in stale children being displayed.
 *
 * Cache hit conditions:
 * 1. The component class must be the same reference
 * 2. The args object must be shallowly equal
 *
 * @param {Map<string, {ComponentClass: typeof Component, args: Object, result: Object}>} cache - The component cache keyed by stable block keys.
 * @param {Object} entry - The block entry with __stableKey and optional children.
 * @param {typeof Component} resolvedBlock - The resolved block component class.
 * @param {Object} debugContext - Debug context containing key, hierarchy, conditions, and outletArgs.
 * @param {import("@ember/owner").default} owner - The application owner for service lookup.
 * @returns {{Component: import("ember-curry-component").CurriedComponent, containerArgs: Object|undefined, key: string}}
 *   The cached or newly created component data with stable key for list rendering.
 */
function getOrCreateLeafBlockComponent(
  cache,
  entry,
  resolvedBlock,
  debugContext,
  owner
) {
  const { key } = debugContext;
  const cachedEntry = cache.get(key);
  const hasChildren = entry.children?.length > 0;

  // Only cache leaf blocks (no children). Container blocks are always recreated
  // to ensure their children reflect current visibility state.
  if (
    !hasChildren &&
    cachedEntry &&
    cachedEntry.ComponentClass === resolvedBlock &&
    shallowArgsEqual(cachedEntry.args, entry.args)
  ) {
    return cachedEntry.result;
  }

  // Create new curried component
  const result = createChildBlock(
    { ...entry, block: resolvedBlock },
    owner,
    debugContext
  );

  // Cache leaf blocks for future reuse
  if (!hasChildren) {
    cache.set(key, {
      ComponentClass: resolvedBlock,
      args: entry.args,
      result,
    });
  }

  return result;
}

/**
 * Processes block entries and creates renderable child components.
 *
 * This function iterates through a list of pre-processed block entries and
 * transforms them into renderable components, handling ghost blocks for
 * debug mode and optional missing blocks.
 *
 * @typedef {Object} BlockEntry
 * @property {string|typeof Component} block - Block reference (string name or class).
 * @property {Object} [args] - Arguments to pass to the block.
 * @property {Object} [containerArgs] - Values for parent container's childArgs schema.
 * @property {Array<BlockEntry>} [children] - Nested block entries for containers.
 * @property {Object|Array<Object>} [conditions] - Conditions that must pass for block to render.
 * @property {string} [classNames] - Additional CSS classes for the block wrapper.
 * @property {boolean} __visible - Whether the block passed condition evaluation.
 * @property {number} __stableKey - Stable key assigned at registration time.
 * @property {string} [__failureReason] - Why the block is hidden (debug mode only).
 *
 * @typedef {Object} ChildBlockResult
 * @property {import("ember-curry-component").CurriedComponent} Component - Curried component ready to render.
 * @property {Object} [containerArgs] - Values for parent container's childArgs schema.
 * @property {string} key - Stable unique key for list rendering.
 *
 * @param {Object} options - Rendering options.
 * @param {Array<BlockEntry>} options.entries - Pre-processed block entries with visibility metadata.
 * @param {Map<string, {ComponentClass: typeof Component, args: Object, result: ChildBlockResult}>} options.cache - Component cache keyed by stable block keys.
 * @param {import("@ember/owner").default} options.owner - Application owner for service lookup.
 * @param {string} options.baseHierarchy - Current hierarchy path (e.g., "homepage-blocks/section-1").
 * @param {string} options.outletName - The outlet name for CSS class generation.
 * @param {Object} options.outletArgs - Arguments passed from the outlet to blocks.
 * @param {boolean} options.showGhosts - Whether to render ghost blocks for invisible entries.
 * @param {boolean} options.isLoggingEnabled - Whether debug logging is active.
 * @returns {Array<ChildBlockResult>} Array of renderable child objects with Component and containerArgs.
 */
function processBlockEntries({
  entries,
  cache,
  owner,
  baseHierarchy,
  outletName,
  outletArgs,
  showGhosts,
  isLoggingEnabled,
}) {
  const result = [];
  const containerCounts = new Map();

  for (const entry of entries) {
    // @ts-ignore - entry.block can be string or BlockClass
    const resolvedBlock = resolveBlockSync(entry.block);

    // Handle optional missing block (block ref ended with `?` but not registered)
    if (isOptionalMissing(resolvedBlock)) {
      const key = `optional-missing:${resolvedBlock.name}:${entry.__stableKey}`;
      const ghostData = handleOptionalMissingBlock({
        blockName: resolvedBlock.name,
        entry,
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

    // Skip blocks that haven't resolved yet. This is intentional - block factories
    // may be resolving asynchronously (e.g., lazy-loaded plugins). The block will
    // render on the next pass once its factory resolves.
    if (!resolvedBlock) {
      continue;
    }

    const blockClass =
      /** @type {import("discourse/lib/blocks/-internals/registry/block").BlockClass} */ (
        resolvedBlock
      );
    const blockName = blockClass.blockName || "unknown";
    const isContainer = isContainerBlock(blockClass);

    // Use the stable key assigned at registration time. This key survives
    // shallow cloning and ensures DOM identity is maintained when blocks
    // are hidden/shown by conditions.
    const key = `${blockName}:${entry.__stableKey}`;

    // For containers, build their full path for children's hierarchy
    const containerPath = isContainer
      ? buildContainerPath(blockName, baseHierarchy, containerCounts)
      : undefined;

    // Render visible blocks
    if (entry.__visible) {
      result.push(
        getOrCreateLeafBlockComponent(
          cache,
          entry,
          blockClass,
          {
            displayHierarchy: baseHierarchy,
            outletName,
            containerPath,
            conditions: entry.conditions,
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
        entry,
        hierarchy: baseHierarchy,
        containerPath,
        isContainer,
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
 * Creates the args object for a child block with reactive getters for context args.
 *
 * Block args come from two sources:
 * 1. **Entry args** (`entryArgs`) - Defined in layout entries by theme/plugin authors.
 *    These are spread directly onto the block args object.
 * 2. **Context args** (`contextArgs`) - Framework-provided values that describe the
 *    rendering context: where the block is rendered (`outletName`), what data is
 *    available (`outletArgs`), and structural info (`children`, `__hierarchy`).
 *
 * Context args are defined as getters rather than direct properties. This allows
 * `curryComponent` to maintain a stable component identity while enabling reactive
 * updates when the getter values change. Without getters, changing any arg would
 * require creating a new curried component, breaking Ember's identity-based rendering.
 *
 * @param {Object} entryArgs - User-provided args from the layout entry.
 * @param {Object} contextArgs - Rendering context to define as reactive getters. Each
 *   key becomes an enumerable getter property on the returned args object. Common
 *   context args include:
 *   - `children` - Nested children block configs (for container blocks)
 *   - `__hierarchy` - Debug hierarchy path for developer tools
 *   - `outletArgs` - Args passed from the parent outlet
 *   - `outletName` - The outlet identifier where this block is rendered
 * @returns {Object} The merged args object ready for `curryComponent`.
 */
function createBlockArgsWithReactiveGetters(entryArgs, contextArgs) {
  const blockArgs = {
    ...entryArgs,
    $block$: __BLOCK_CONTAINER_FLAG,
  };

  // Dynamically define reactive getters for each context arg
  /** @type {PropertyDescriptorMap} */
  const propertyDescriptors = {};
  for (const [key, value] of Object.entries(contextArgs)) {
    propertyDescriptors[key] = {
      get() {
        return value;
      },
      enumerable: true,
    };
  }
  Object.defineProperties(blockArgs, propertyDescriptors);

  return blockArgs;
}

/**
 * Resolves the containerClassNames value from block metadata.
 * Handles string, array, and function forms.
 *
 * @param {Object} metadata - The block metadata object.
 * @param {Object} args - The block's args (passed to function form).
 * @returns {string|null} The resolved class names string, or null if none.
 */
function resolveContainerClassNames(metadata, args) {
  const value = metadata.containerClassNames;
  if (value == null) {
    return null;
  }
  if (typeof value === "function") {
    return value(args);
  }
  if (Array.isArray(value)) {
    return value.join(" ");
  }
  return value;
}

/**
 * Creates a renderable child block from a block entry.
 * Curries the component with all necessary args and wraps all blocks
 * in a layout wrapper for consistent styling.
 *
 * @param {Object} entry - The block entry
 * @param {import("discourse/lib/blocks/-internals/registry/block").BlockClass} entry.block - The block component class
 * @param {Object} [entry.args] - Args to pass to the block
 * @param {Object} [entry.containerArgs] - Container args for parent's childArgs schema
 * @param {string} [entry.classNames] - Additional CSS classes
 * @param {Array<Object>} [entry.children] - Nested block entries
 * @param {import("@ember/owner").default} owner - The application owner
 * @param {Object} [debugContext] - Debug context for visual overlay
 * @param {string} [debugContext.displayHierarchy] - Where the block is rendered (for tooltip display)
 * @param {string} [debugContext.containerPath] - Container's full path (for children's __hierarchy)
 * @param {Object} [debugContext.conditions] - The block's conditions
 * @param {Object} [debugContext.outletArgs] - Outlet args for debug display
 * @param {string} [debugContext.key] - Stable unique key for this block
 * @param {string} [debugContext.outletName] - The outlet name for wrapper class generation
 * @returns {{Component: import("ember-curry-component").CurriedComponent, containerArgs: Object|undefined, key: string}}
 *   An object containing the curried block component, any containerArgs
 *   provided in the block entry, and a stable unique key for list rendering.
 *   The containerArgs are values required by the parent container's childArgs
 *   schema, accessible to the parent but not to the child block itself.
 */
function createChildBlock(entry, owner, debugContext = {}) {
  const {
    block: ComponentClass,
    args = {},
    containerArgs,
    classNames,
    children: nestedChildren,
  } = entry;
  const isContainer = isContainerBlock(ComponentClass);

  // Apply default values from metadata before building args
  const argsWithDefaults = applyArgDefaults(ComponentClass, args);

  // All blocks use the same arg structure - classNames are handled by wrappers.
  // Pass containerPath so nested containers know their full path for debug logging.
  const blockArgs = createBlockArgsWithReactiveGetters(argsWithDefaults, {
    children: nestedChildren,
    outletArgs: debugContext.outletArgs,
    outletName: debugContext.outletName,
    __hierarchy: isContainer
      ? debugContext.containerPath
      : debugContext.displayHierarchy,
  });

  // Curry the component with pre-bound args so it can be rendered
  // without knowing its configuration details
  const curried = curryComponent(ComponentClass, blockArgs, owner);

  // All blocks are wrapped for consistent styling
  let wrappedComponent = wrapBlockLayout(
    {
      name: ComponentClass.blockName,
      outletName: debugContext.outletName,
      isContainer,
      containerClassNames: isContainer
        ? resolveContainerClassNames(
            ComponentClass.blockMetadata,
            argsWithDefaults
          )
        : null,
      classNames,
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
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
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
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 *
 * @param {Function} component - The component to check
 * @returns {boolean} True if the component is registered as a container block, false otherwise
 */
export function isContainerBlock(component) {
  return !!component?.[__BLOCK_CONTAINER_FLAG];
}

/**
 * Registers an outlet layout (array of block entries) for a named outlet.
 *
 * This is the main entry point for plugins to render blocks in designated areas.
 * Each outlet can only have one layout registered. In development mode,
 * attempting to register a second layout throws an error; in production,
 * it logs a warning.
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 *
 * @param {string} outletName - The outlet identifier (must be in BLOCK_OUTLETS).
 * @param {Array<LayoutEntry>} layout - Array of block entries.
 * @param {Object} [owner] - The application owner for service lookup (passed from plugin API).
 * @param {Error|null} [callSiteError] - Pre-captured error for source-mapped stack traces.
 *   When called via api.renderBlocks(), this is captured there to exclude the PluginApi wrapper.
 * @returns {Promise<Array<Object>>} Promise resolving to the validated layout array.
 * @throws {Error} If validation fails or outlet already has a layout (in DEBUG mode).
 *
 * @example
 * ```js
 * import { renderBlocks } from "discourse/blocks/block-outlet";
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
export function renderBlocks(outletName, layout, owner, callSiteError = null) {
  // Use provided call site error, or capture one here as fallback.
  // When called via api.renderBlocks(), the call site is captured there
  // to exclude the PluginApi wrapper from the stack trace.
  if (!callSiteError) {
    callSiteError = captureCallSite(renderBlocks);
  }

  // === Synchronous validation for outlet-level checks ===
  // These don't depend on block resolution and can fail fast.

  // Check for duplicate registration before anything else
  if (outletLayouts.has(outletName)) {
    raiseBlockError(
      `Block outlet "${outletName}" already has a layout registered.`
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

  // Assign stable keys to all entries before validation. These keys survive
  // shallow cloning in #preprocessEntries and ensure Ember maintains DOM
  // identity when blocks are hidden/shown by conditions.
  assignStableKeys(layout);

  // All block validation is async (handles both class refs and string refs).
  // In dev mode, this eagerly resolves all factories for early error detection.
  // In prod, it defers factory resolution to render time.
  //
  // Validation errors are reported via raiseBlockError() which:
  // - In DEBUG: throws (surfacing as unhandled rejection in console)
  // - In prod: dispatches a 'block-error' event
  //
  // The promise is returned so tests can await and catch errors.
  const validatedLayout = validateLayout(
    layout,
    outletName,
    blocksService,
    isBlock,
    isContainerBlock,
    "", // parentPath - empty so paths start with array index like [0]
    callSiteError // Error object for source-mapped call site
  ).then(() => layout);

  // Store layout with validation promise for potential future use
  outletLayouts.set(outletName, { validatedLayout });

  return validatedLayout;
}

/**
 * Checks if a layout has been registered for a given outlet.
 * Used in templates to conditionally render content based on block presence.
 *
 * @param {string} outletName - The outlet identifier to check.
 * @returns {boolean} True if a layout is registered for this outlet.
 */
function hasLayout(outletName) {
  return outletLayouts.has(outletName);
}

/**
 * Root component for rendering registered blocks in a designated outlet.
 *
 * BlockOutlet serves as the entry point for the block rendering system. It:
 * - Looks up registered layouts by outlet name
 * - Renders blocks in a consistent wrapper structure
 * - Provides named blocks (`<:before>`, `<:after>`) for conditional content
 *
 * Named blocks:
 * - `<:before>` - Yields `hasLayout` boolean before block content.
 * - `<:after>` - Yields `hasLayout` boolean after block content.
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
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
// @ts-ignore - TS1238/TS1270: Decorator return type issues with @block
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
    // @ts-ignore - TS2556: Spread argument for parent class constructor
    super(...arguments);

    // Lock the name at construction to prevent dynamic changes
    this.#name = this.args.name;

    if (!BLOCK_OUTLETS.includes(this.#name)) {
      raiseBlockError(
        `Block outlet ${this.#name} is not registered in the blocks registry`
      );
    }
  }

  get validatedLayout() {
    return outletLayouts.get(this.#name)?.validatedLayout;
  }

  /**
   * Processes block entries and returns renderable components.
   *
   * This is the root-level implementation that:
   * 1. Gets raw entries from the outlet layout registry
   * 2. Preprocesses them to evaluate conditions and compute visibility
   * 3. Creates renderable components from visible blocks
   * 4. Creates ghost components for invisible blocks (in debug mode)
   *
   * The decorator's `children` getter defers to this for root blocks,
   * while nested containers use their own simplified logic since
   * their entries are already preprocessed by their parent.
   *
   * Each child object contains:
   * - `Component`: The curried block component ready to render
   * - `containerArgs`: Values provided by the child entry for the parent's
   *   `childArgs` schema (accessible to parent, not the child block itself)
   *
   * @returns {TrackedAsyncData<{rawChildren: Array<Object>, showGhosts: boolean, isLoggingEnabled: boolean}|undefined>|undefined}
   *   TrackedAsyncData wrapper containing the raw children and debug state once the
   *   layout is validated. Use .isResolved, .value, .isRejected, .error to access state.
   */
  @cached
  get children() {
    // we need to track the state outside the promise contexts to force the children to be rendered when
    // the user enables the debugging
    const showGhosts = debugHooks.isVisualOverlayEnabled;
    const isLoggingEnabled = debugHooks.isBlockLoggingEnabled;

    if (!this.validatedLayout) {
      return;
    }

    /* Block entries are validated asynchronously. TrackedAsyncData lets us wait
       for validation to complete before rendering blocks, while also exposing
       any validation errors to the debug overlay.

       Note: We intentionally do NOT evaluate conditions here. Condition evaluation
       happens in BlockOutletRootContainer.processedChildren so that service reads
       (router.currentURL, discovery.category, etc.) are tracked by Ember's
       autotracking system. If we evaluated conditions inside this promise, route
       changes would not trigger re-evaluation. */
    const promiseWithLogging = this.validatedLayout
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
        // - Validation errors (from validateLayout): Already fail tests as
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
    // @ts-ignore - callback is typed as Function but is actually a Component
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
    return this.children.value?.rawChildren?.length ?? 0;
  }

  /**
   * Validation error if the outlet layout failed validation.
   * Only accessible when the validation promise has rejected.
   *
   * @returns {Error|null}
   */
  get validationError() {
    const asyncData =
      /** @type {{isRejected?: boolean, error?: Error}|undefined} */ (
        this.children
      );
    if (!asyncData?.isRejected) {
      return null;
    }
    return asyncData.error ?? null;
  }

  /**
   * Combines `@outletArgs` with `@deprecatedArgs` for lazy evaluation.
   *
   * Outlet args are values passed from the parent template to blocks rendered
   * in this outlet. They are separate from layout entry args and accessed via
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
    {{! yield to :before block with hasLayout boolean for conditional rendering
        This allows block outlets to wrap other elements and conditionally render them based on
        the presence of a registered layout if necessary }}
    {{! @glint-expect-error - yield signature not typed }}
    {{yield (hasLayout this.outletName) to="before"}}

    {{#if this.showOutletBoundary}}
      <div
        class={{concatClass
          "block-outlet-debug"
          (if this.children.isRejected "--validation-failed")
        }}
        data-outlet-name={{this.outletName}}
      >
        {{#if this.OutletInfoComponent}}
          {{! @glint-expect-error - dynamic component invocation }}
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

    {{! yield to :after block with hasLayout boolean for conditional rendering
        This allows block outlets to wrap other elements and conditionally render them based on
        the presence of a registered layout if necessary }}
    {{! @glint-expect-error - yield signature not typed }}
    {{yield (hasLayout this.outletName) to="after"}}
  </template>
}

/**
 * Internal container component that processes and renders block children.
 *
 * This component handles condition evaluation and component creation in a
 * tracked getter context. By evaluating conditions synchronously in
 * `processedChildren`, Ember's autotracking establishes dependencies on
 * services like `router` and `discovery`. Route changes trigger re-evaluation.
 *
 * If condition evaluation happened in the async promise chain (as it did
 * previously), service reads would not be tracked and route navigation
 * would not trigger re-evaluation.
 *
 * @private
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
   * Processes raw block entries and creates renderable child components.
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
    const processedEntries = this.#preprocessEntries(
      rawChildren,
      outletArgs,
      this.blocks,
      showGhosts,
      isLoggingEnabled,
      baseHierarchy
    );

    // Step 2: Create components from processed entries
    // @ts-ignore - TS2322: ChildBlockResult type compatible with return type
    return processBlockEntries({
      entries: processedEntries,
      cache: this.#componentCache,
      owner,
      baseHierarchy,
      outletName,
      outletArgs,
      showGhosts,
      isLoggingEnabled,
    });
  }

  /**
   * Pre-processes block entries to compute visibility for all blocks.
   *
   * This method evaluates conditions for all blocks in the tree and adds
   * visibility metadata to each entry:
   * - `__visible`: Whether the block should be rendered
   * - `__failureReason`: Why the block is hidden (debug mode only)
   *
   * Container blocks have an implicit condition: they must have at least
   * one visible child. This is evaluated bottom-up (children first).
   *
   * @param {Array<Object>} entries - Array of block entries to process.
   * @param {Object} outletArgs - Outlet arguments for condition evaluation.
   * @param {Object} blocksService - Blocks service for condition evaluation.
   * @param {boolean} showGhosts - If true, keep all blocks for ghost rendering.
   * @param {boolean} isLoggingEnabled - If true, log condition evaluation.
   * @param {string} baseHierarchy - Base hierarchy path for logging.
   * @returns {Array<Object>} Processed entries with visibility metadata.
   */
  #preprocessEntries(
    entries,
    outletArgs,
    blocksService,
    showGhosts,
    isLoggingEnabled,
    baseHierarchy
  ) {
    const result = [];

    for (const entry of entries) {
      // Shallow clone to add visibility metadata without mutating the original
      // layout entry. The layout is immutable after registration, so we create
      // a copy to attach __visible and __failureReason properties.
      const entryClone = { ...entry };

      // Resolve block reference
      const resolvedBlock = resolveBlockSync(entryClone.block);

      // Skip unresolved blocks (optional missing or pending factory resolution)
      if (!resolvedBlock || isOptionalMissing(resolvedBlock)) {
        // Keep the entry for ghost handling in the main loop
        if (showGhosts || isOptionalMissing(resolvedBlock)) {
          result.push(entryClone);
        }
        continue;
      }

      const blockClass =
        /** @type {import("discourse/lib/blocks/-internals/registry/block").BlockClass} */ (
          resolvedBlock
        );
      const blockName = blockClass.blockName || "unknown";
      const isContainer = isContainerBlock(blockClass);

      // Evaluate this block's own conditions.
      // The withDebugGroup wrapper ensures START_GROUP/END_GROUP are always paired.
      // This is the key reactive line - blocksService.evaluate() reads from router/discovery
      // services, and since we're in a tracked getter, Ember tracks these reads.
      const conditionsPassed = entryClone.conditions
        ? withDebugGroup(blockName, baseHierarchy, isLoggingEnabled, () =>
            blocksService.evaluate(entryClone.conditions, {
              debug: isLoggingEnabled,
              outletArgs,
            })
          )
        : true;

      // For containers: recursively process children first (bottom-up evaluation)
      // This determines which children are visible before we check if container has any
      let hasVisibleChildren = true; // Non-containers always "have" visible children
      if (isContainer && entryClone.children?.length) {
        // Recursively preprocess children - this computes their visibility
        const processedChildren = this.#preprocessEntries(
          entryClone.children,
          outletArgs,
          blocksService,
          showGhosts,
          isLoggingEnabled,
          `${baseHierarchy}/${blockName}`
        );

        hasVisibleChildren = processedChildren.some((child) => child.__visible);

        // Update the cloned entry's children with the processed result
        entryClone.children = processedChildren;
      }

      // Final visibility: own conditions must pass AND (not container OR has visible children)
      // This implements the implicit "container must have visible children" condition
      const visible = conditionsPassed && hasVisibleChildren;
      entryClone.__visible = visible;

      // In debug mode, record why the block is hidden for the ghost tooltip
      if (showGhosts && !visible) {
        entryClone.__failureReason = !conditionsPassed
          ? "condition-failed"
          : "no-visible-children";
      }

      // In production mode, filter out invisible blocks
      // In debug mode, keep all blocks for ghost rendering
      if (visible || showGhosts) {
        result.push(entryClone);
      }
    }

    return result;
  }

  <template>
    <div class={{@outletName}}>
      <div class="{{@outletName}}__container">
        <div class="{{@outletName}}__layout">
          {{#each this.processedChildren key="key" as |child|}}
            <child.Component />
          {{/each}}
        </div>
      </div>
    </div>
  </template>
}
