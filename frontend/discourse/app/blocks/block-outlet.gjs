// @ts-check
/**
 * BlockOutlet System
 *
 * This module provides the BlockOutlet component and outlet layout management.
 * BlockOutlet is the root entry point for rendering blocks in designated areas.
 *
 * This file handles:
 * - BlockOutlet component
 * - Outlet layout registration and management
 * - Child block creation and rendering
 */
import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { cached } from "@glimmer/tracking";
import curryComponent from "ember-curry-component";
/** @type {import("discourse/components/async-content.gjs")} */
import AsyncContent from "discourse/components/async-content";
/** @type {import("discourse/lib/blocks/-internals/components/block-layout-wrapper.gjs")} */
import { wrapBlockLayout } from "discourse/lib/blocks/-internals/components/block-layout-wrapper";
/** @type {import("discourse/lib/blocks/-internals/components/block-outlet-inline-error.gjs")} */
import BlockOutletInlineError from "discourse/lib/blocks/-internals/components/block-outlet-inline-error";
/** @type {import("discourse/lib/blocks/-internals/components/block-outlet-root-container.gjs")} */
import BlockOutletRootContainer from "discourse/lib/blocks/-internals/components/block-outlet-root-container";
import {
  createDebugGhost,
  DEBUG_CALLBACK,
  debugHooks,
} from "discourse/lib/blocks/-internals/debug-hooks";
import {
  block,
  createBlockArgsWithReactiveGetters,
  getBlockMetadata,
} from "discourse/lib/blocks/-internals/decorator";
import {
  captureCallSite,
  raiseBlockError,
} from "discourse/lib/blocks/-internals/error";
import { isBlockRegistryFrozen } from "discourse/lib/blocks/-internals/registry/block";
import { applyArgDefaults } from "discourse/lib/blocks/-internals/utils";
import { validateLayout } from "discourse/lib/blocks/-internals/validation/layout";
import { isRailsTesting, isTesting } from "discourse/lib/environment";
import { buildArgsWithDeprecations } from "discourse/lib/outlet-args";
import { BLOCK_OUTLETS } from "discourse/lib/registry/block-outlets";

/**
 * A block entry in a layout configuration.
 *
 * @typedef {Object} LayoutEntry
 * @property {typeof Component} block - The block component class (must use @block decorator).
 * @property {Object} [args] - Args to pass to the block component.
 * @property {string|string[]} [classNames] - Additional CSS classes for the block wrapper.
 * @property {Array<LayoutEntry>} [children] - Nested block entries (only for container blocks).
 * @property {Array<Object>|Object} [conditions] - Conditions that must pass for block to render.
 * @property {Object} [containerArgs] - Args passed from parent container's childArgs.
 */

/**
 * Maps outlet names to their registered outlet layouts.
 * Each outlet can have exactly one layout registered.
 *
 * DO NOT EXPORT THIS MAP to prevent layouts bypassing the validation steps
 *
 * @type {Map<string, {validatedLayout: Promise<Array<Object>>}>}
 */
const outletLayouts = new Map();

/**
 * Counter for generating stable entry keys.
 * Incremented for each block entry when a layout is registered via `_renderBlocks()`.
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
 * Keys are assigned at registration time (in `_renderBlocks()`) rather than
 * render time, ensuring they survive the shallow cloning in `BlockOutletRootContainer#preprocessEntries`.
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
export function _resetOutletLayoutsForTesting() {
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
 * @returns {Map<string, {validatedLayout: Promise<Array<Object>>}>} The outlet layouts map.
 */
export function _getOutletLayouts() {
  if (DEBUG) {
    return outletLayouts;
  }
  return new Map();
}

/**
 * Resolves the decoratorClassNames value from block metadata.
 * Handles string, array, and function forms.
 *
 * @param {Object} metadata - The block metadata object.
 * @param {Object} args - The block's args (passed to function form).
 * @returns {string|null} The resolved class names string, or null if none.
 */
function resolveDecoratorClassNames(metadata, args) {
  const value = metadata.decoratorClassNames;
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
 * @param {string} [entry.id] - Unique identifier for BEM styling and targeting
 * @param {import("@ember/owner").default} owner - The application owner
 * @param {Object} [debugContext] - Debug context for visual overlay
 * @param {string} [debugContext.displayHierarchy] - Where the block is rendered (for tooltip display)
 * @param {string} [debugContext.containerPath] - Container's full path (for children's __hierarchy)
 * @param {Object} [debugContext.conditions] - The block's conditions
 * @param {Object} [debugContext.outletArgs] - Outlet args for debug display
 * @param {string} [debugContext.key] - Stable unique key for this block
 * @param {string} [debugContext.outletName] - The outlet name for wrapper class generation
 * @param {Array<import("discourse/lib/blocks/-internals/entry-processing").ChildBlockResult>} [debugContext.processedChildren] - Pre-processed children
 * @returns {import("discourse/lib/blocks/-internals/entry-processing").ChildBlockResult}
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
    id,
  } = entry;
  const blockMeta = getBlockMetadata(ComponentClass);
  const isContainer = blockMeta?.isContainer ?? false;

  // Apply default values from metadata before building args
  const argsWithDefaults = applyArgDefaults(ComponentClass, args);

  // Create block args with authorization token embedded.
  // classNames are handled by wrappers, containerPath provides full path for debug logging.
  const blockArgs = createBlockArgsWithReactiveGetters(argsWithDefaults, {
    children: debugContext.processedChildren,
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
      name: blockMeta?.blockName,
      namespace: blockMeta?.namespace,
      outletName: debugContext.outletName,
      isContainer,
      id,
      decoratorClassNames: resolveDecoratorClassNames(
        blockMeta,
        argsWithDefaults
      ),
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
        name: blockMeta?.blockName,
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

  /** @type {import("discourse/lib/blocks/-internals/entry-processing").ChildBlockResult} */
  const result = {
    Component: wrappedComponent,
    containerArgs,
    key: debugContext.key,
    /**
     * Returns a ghost version of this child with a custom failure reason.
     *
     * Used by container blocks (like head) that choose not to render some children
     * but want to show them as ghosts in debug mode with an explanation.
     *
     * @param {string} reason - The failure reason to display in the ghost overlay.
     * @returns {import("discourse/lib/blocks/-internals/entry-processing").ChildBlockResult|null}
     *   A ghost child block result, or null if debug mode is disabled.
     */
    asGhost(reason) {
      const ghostResult = createDebugGhost(
        {
          name: blockMeta?.blockName,
          args: argsWithDefaults,
          containerArgs,
          conditions: debugContext.conditions,
          failureReason: reason,
        },
        {
          outletName: debugContext.displayHierarchy,
          outletArgs: debugContext.outletArgs,
        }
      );

      if (ghostResult) {
        /** @type {import("discourse/lib/blocks/-internals/entry-processing").ChildBlockResult} */
        const ghostChild = {
          Component: ghostResult.Component,
          containerArgs,
          key: `${debugContext.key}:ghost`,
          isGhost: true,
          asGhost: () => ghostChild,
        };
        return ghostChild;
      }

      return null;
    },
  };

  return result;
}

/**
 * Registers an outlet layout (array of block entries) for a named outlet.
 *
 * This is the main entry point for plugins to render blocks in designated areas.
 * Each outlet can only have one layout registered. Attempting to register a
 * second layout throws an error.
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
 * @throws {Error} If validation fails or outlet already has a layout.
 *
 * @example
 * ```js
 * // This is an internal function. Plugins should use api.renderBlocks() instead.
 * // import { _renderBlocks } from "discourse/blocks/block-outlet";
 *
 * api.renderBlocks("homepage-blocks", [
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
export function _renderBlocks(outletName, layout, owner, callSiteError = null) {
  if (!callSiteError) {
    callSiteError = captureCallSite(_renderBlocks);
  }

  // Check for duplicate registration
  if (outletLayouts.has(outletName)) {
    raiseBlockError(
      `Block outlet "${outletName}" already has a layout registered.`
    );
  }

  // Validate outlet name is known
  if (!BLOCK_OUTLETS.includes(outletName)) {
    raiseBlockError(`Unknown block outlet: ${outletName}`);
  }

  // Verify registries are frozen
  if (!isBlockRegistryFrozen()) {
    raiseBlockError(
      `api.renderBlocks() was called before the block registry was frozen. ` +
        `Move your code to an initializer that runs after "freeze-block-registry". ` +
        `Outlet: "${outletName}"`
    );
  }

  const blocksService = owner?.lookup("service:blocks");

  // Assign stable keys to all entries
  assignStableKeys(layout);

  // Validate layout asynchronously
  const validatedLayout = validateLayout(
    layout,
    outletName,
    blocksService,
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
 * Component signature for BlockOutlet.
 *
 * @typedef {Object} BlockOutletSignature
 * @property {Object} Args
 * @property {string} Args.name - The outlet name (must be in BLOCK_OUTLETS registry).
 * @property {Object} [Args.outletArgs] - Arguments to pass to blocks rendered in this outlet.
 * @property {Object} [Args.deprecatedArgs] - Deprecated args with deprecation warnings.
 * @property {Object} Blocks
 * @property {[hasLayout: boolean]} Blocks.before - Yields hasLayout flag before content.
 * @property {[hasLayout: boolean]} Blocks.after - Yields hasLayout flag after content.
 * @property {[error: Error]} Blocks.error - Yields error when validation fails.
 */

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
 * @extends {Component<BlockOutletSignature>}
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
@block("block-outlet", { container: true, root: true })
export default class BlockOutlet extends Component {
  /**
   * The outlet name, locked at construction time.
   * This prevents dynamic name changes which could cause inconsistent rendering.
   *
   * @type {string}
   */
  #name;

  constructor(owner, args) {
    super(owner, args);

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
   * @returns {Promise<{rawChildren: Array<Object>, showGhosts: boolean, isLoggingEnabled: boolean}>|undefined}
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

        return { rawChildren, showGhosts, isLoggingEnabled };
      })
      .catch((error) => {
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

    return promiseWithLogging;
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
   * The component to render for outlet boundary debug info.
   * Returns the OutletInfo component when debug mode is enabled, null otherwise.
   *
   * @returns {typeof Component|null}
   */
  get OutletInfoComponent() {
    return debugHooks.outletInfoComponent;
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
    {{yield (hasLayout this.outletName) to="before"}}

    {{#let
      (if
        this.OutletInfoComponent
        (component
          this.OutletInfoComponent
          outletName=this.outletName
          outletArgs=this.outletArgsWithDeprecations
          blockCount=0
          error=null
        )
      )
      as |OutletInfo|
    }}
      <AsyncContent @asyncData={{this.children}}>
        <:loading>
          {{! Resolving async blocks should not display a loading UI }}
        </:loading>

        <:content as |layout|>
          {{#let
            (component
              BlockOutletRootContainer
              outletName=this.outletName
              outletArgs=this.outletArgsWithDeprecations
              rawChildren=layout.rawChildren
              showGhosts=layout.showGhosts
              isLoggingEnabled=layout.isLoggingEnabled
              createChildBlockFn=createChildBlock
            )
            as |ChildrenContainer|
          }}
            {{#if OutletInfo}}
              <OutletInfo @blockCount={{layout.rawChildren.length}}>
                <ChildrenContainer />
              </OutletInfo>
            {{else}}
              <ChildrenContainer />
            {{/if}}
          {{/let}}
        </:content>

        <:error as |error|>
          {{#if OutletInfo}}
            <OutletInfo @error={{error}}>
              {{#if (has-block "error")}}
                {{yield error to="error"}}
              {{else}}
                <BlockOutletInlineError @error={{error}} />
              {{/if}}
            </OutletInfo>
          {{else if (has-block "error")}}
            {{yield error to="error"}}
          {{else}}
            <BlockOutletInlineError @error={{error}} />
          {{/if}}
        </:error>

        <:empty>
          {{#if OutletInfo}}
            <OutletInfo />
          {{/if}}
        </:empty>
      </AsyncContent>
    {{/let}}

    {{! yield to :after block with hasLayout boolean for conditional rendering
        This allows block outlets to wrap other elements and conditionally render them based on
        the presence of a registered layout if necessary }}
    {{yield (hasLayout this.outletName) to="after"}}
  </template>
}
