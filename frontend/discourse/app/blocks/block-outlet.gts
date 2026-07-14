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
import type Owner from "@ember/owner";
import curryComponent from "ember-curry-component";
import type { BlockMetadata, LayoutEntry } from "discourse/blocks/types";
import { wrapBlockLayout } from "discourse/lib/blocks/-internals/components/block-layout-wrapper";
import BlockOutletInlineError from "discourse/lib/blocks/-internals/components/block-outlet-inline-error";
import BlockOutletRootContainer from "discourse/lib/blocks/-internals/components/block-outlet-root-container";
import {
  createDebugGhost,
  DEBUG_CALLBACK,
  type DebugGhostData,
  debugHooks,
} from "discourse/lib/blocks/-internals/debug-hooks";
import {
  block,
  createBlockArgsWithReactiveGetters,
  getBlockMetadata,
  registerRootBlock,
} from "discourse/lib/blocks/-internals/decorator";
import type { CreateChildBlockFn } from "discourse/lib/blocks/-internals/entry-processing";
import {
  captureCallSite,
  raiseBlockError,
} from "discourse/lib/blocks/-internals/error";
import { isBlockRegistryFrozen } from "discourse/lib/blocks/-internals/registry/block";
import type {
  BlockClass,
  BlockComponent,
  BlockEntry,
  ChildBlockResult,
} from "discourse/lib/blocks/-internals/types";
import { applyArgDefaults } from "discourse/lib/blocks/-internals/utils";
import { validateLayout } from "discourse/lib/blocks/-internals/validation/layout";
import { isRailsTesting, isTesting } from "discourse/lib/environment";
import { buildArgsWithDeprecations } from "discourse/lib/outlet-args";
import { BLOCK_OUTLETS } from "discourse/lib/registry/block-outlets";
import type Blocks from "discourse/services/blocks";
import DAsyncContent from "discourse/ui-kit/d-async-content";

/**
 * Maps outlet names to their registered outlet layouts.
 * Each outlet can have exactly one layout registered.
 *
 * DO NOT EXPORT THIS MAP to prevent layouts bypassing the validation steps
 */
const outletLayouts = new Map<
  string,
  { validatedLayout: Promise<BlockEntry[]> }
>();

/**
 * Counter for generating stable entry keys.
 * Incremented for each block entry when a layout is registered via `_renderBlocks()`.
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
 */
function assignStableKeys(entries: BlockEntry[]): void {
  for (const entry of entries) {
    entry.__stableKey = nextEntryKey++;

    // Recursively assign keys to children
    const children = entry.children;
    if (children?.length) {
      assignStableKeys(children);
    }
  }
}

/**
 * Clears all registered outlet layouts.
 *
 * USE ONLY FOR TESTING PURPOSES.
 */
export function _resetOutletLayoutsForTesting(): void {
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
 */
export function _getOutletLayouts(): Map<
  string,
  { validatedLayout: Promise<BlockEntry[]> }
> {
  if (DEBUG) {
    return outletLayouts;
  }
  return new Map();
}

/**
 * Resolves the decoratorClassNames value from block metadata.
 * Handles string, array, and function forms.
 */
function resolveDecoratorClassNames(
  metadata: BlockMetadata | null,
  args: Record<string, unknown>
): string | null {
  const value = metadata?.decoratorClassNames;
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
 * An object containing the curried block component, any containerArgs
 * provided in the block entry, and a stable unique key for list rendering.
 * The containerArgs are values required by the parent container's childArgs
 * schema, accessible to the parent but not to the child block itself.
 */
const createChildBlock: CreateChildBlockFn = (entry, owner, debugContext) => {
  const { block: rawBlock, args = {}, containerArgs, classNames, id } = entry;

  // `entry.block` is `string | BlockClass` because a `BlockEntry` may
  // reference a block by name before resolution; `createChildBlock` is only
  // ever invoked (via `createChildBlockFn`) after `tryResolveBlock` has
  // already resolved the reference to a class, so it is always a
  // `BlockClass` here.
  const ComponentClass = rawBlock as BlockClass;

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
  // without knowing its configuration details. `curryComponent` only refines
  // its return to a `ComponentLike` when the input class is glint-invokable;
  // `ComponentClass` is the deliberately-opaque `BlockClass`, so the generic
  // passes it through unchanged and we assert the known renderable result.
  const curried = curryComponent(
    ComponentClass,
    blockArgs,
    owner
  ) as unknown as BlockComponent;

  // All blocks are wrapped for consistent styling
  let wrappedComponent: BlockComponent = wrapBlockLayout(
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
        id,
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
    ) as DebugGhostData | null | undefined;
    if (debugResult?.Component) {
      wrappedComponent = debugResult.Component;
    }
  }

  const result: ChildBlockResult = {
    Component: wrappedComponent,
    containerArgs,
    key: debugContext.key,

    /**
     * Returns a ghost version of this child with a custom failure reason.
     *
     * Used by container blocks (like head) that choose not to render some children
     * but want to show them as ghosts in debug mode with an explanation.
     */
    asGhost(reason: string): ChildBlockResult | null {
      const ghostResult = createDebugGhost(
        {
          name: blockMeta?.blockName || "unknown",
          id,
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
        const ghostChild: ChildBlockResult = {
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
};

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
 * @param owner - The application owner for service lookup (passed from plugin API).
 * @param callSiteError - Pre-captured error for source-mapped stack traces.
 *   When called via api.renderBlocks(), this is captured there to exclude the PluginApi wrapper.
 *
 * @example
 * ```js
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
export function _renderBlocks(
  outletName: string,
  layout: LayoutEntry[],
  owner?: Owner,
  callSiteError: Error | null = null
): Promise<BlockEntry[]> {
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

  const blocksService = owner?.lookup("service:blocks") as Blocks | undefined;

  // `assignStableKeys` mutates each entry in place, tagging it with the
  // internal `__stableKey` bookkeeping field the rest of the render pipeline
  // relies on. This turns the author-facing `LayoutEntry[]` into the internal
  // `BlockEntry[]` shape used from here on.
  const trackedLayout = layout as unknown as BlockEntry[];
  assignStableKeys(trackedLayout);

  // Validate layout asynchronously
  const validatedLayout = validateLayout(
    layout,
    outletName,
    blocksService,
    "", // parentPath - empty so paths start with array index like [0]
    callSiteError // Error object for source-mapped call site
  ).then(() => trackedLayout);

  // Store layout with validation promise for potential future use
  outletLayouts.set(outletName, { validatedLayout });

  return validatedLayout;
}

/**
 * Checks if a layout has been registered for a given outlet.
 *
 * @internal This is an internal API. Use the `blocks` service's `hasLayout()` method instead.
 */
export function _hasLayout(outletName: string): boolean {
  return outletLayouts.has(outletName);
}

interface BlockOutletSignature {
  Args: {
    // The outlet name (must be in BLOCK_OUTLETS registry).
    name: string;
    // Arguments to pass to blocks rendered in this outlet.
    outletArgs?: Record<string, unknown>;
    // Deprecated args with deprecation warnings.
    deprecatedArgs?: Record<string, unknown>;
  };
  Blocks: {
    // Yields hasLayout flag before content.
    before?: [hasLayout: boolean];
    // Yields hasLayout flag after content.
    after?: [hasLayout: boolean];
    // Yields error when validation fails.
    error?: [error: Error];
  };
}

/** The signature `debugHooks.outletInfoComponent` renders with, when set. */
interface OutletInfoSignature {
  Args: {
    outletName: string;
    blockCount: number;
    outletArgs: Record<string, unknown>;
    error: Error | null;
  };
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
@block("block-outlet", { container: true })
export default class BlockOutlet extends Component<BlockOutletSignature> {
  /**
   * The outlet name, locked at construction time.
   * This prevents dynamic name changes which could cause inconsistent rendering.
   */
  #name: string;

  constructor(owner: Owner, args: BlockOutletSignature["Args"]) {
    super(owner, args);

    // Lock the name at construction to prevent dynamic changes
    this.#name = this.args.name;

    if (!BLOCK_OUTLETS.includes(this.#name)) {
      raiseBlockError(
        `Block outlet ${this.#name} is not registered in the blocks registry`
      );
    }
  }

  get validatedLayout(): Promise<BlockEntry[]> | undefined {
    return outletLayouts.get(this.#name)?.validatedLayout;
  }

  /**
   * Processes block entries and returns renderable components.
   */
  @cached
  get children():
    | Promise<
        | {
            rawChildren: BlockEntry[];
            showGhosts: boolean;
            showVisualOverlay: boolean;
            isLoggingEnabled: boolean;
          }
        | undefined
      >
    | undefined {
    // We need to track the state outside the promise contexts to force the children to be rendered when
    // the user enables the debugging
    const showGhosts = debugHooks.isGhostBlocksEnabled;
    const showVisualOverlay = debugHooks.isVisualOverlayEnabled;
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

        return { rawChildren, showGhosts, showVisualOverlay, isLoggingEnabled };
      })
      .catch((error: unknown) => {
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
   */
  get outletName(): string {
    return this.#name;
  }

  /**
   * The component to render for outlet boundary debug info.
   * Returns the OutletInfo component when debug mode is enabled, null otherwise.
   */
  get OutletInfoComponent():
    | typeof Component<OutletInfoSignature>
    | null
    | undefined {
    // `debugHooks.outletInfoComponent` is typed as a bare `typeof Component`
    // (the debug-hooks module has no reason to know this specific consumer's
    // signature); narrow it to the shape this component actually renders with.
    return debugHooks.outletInfoComponent as
      | typeof Component<OutletInfoSignature>
      | null
      | undefined;
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
   */
  @cached
  get outletArgsWithDeprecations(): Record<string, unknown> {
    if (!this.args.deprecatedArgs) {
      return this.args.outletArgs || {};
    }
    // `buildArgsWithDeprecations` is authored in untyped `.js`; its actual
    // runtime return is a plain object keyed by the combined arg names.
    return buildArgsWithDeprecations(
      this.args.outletArgs || {},
      this.args.deprecatedArgs,
      { outletName: this.#name }
    ) as Record<string, unknown>;
  }

  <template>
    {{! yield to :before block with hasLayout boolean for conditional rendering
        This allows block outlets to wrap other elements and conditionally render them based on
        the presence of a registered layout if necessary }}
    {{yield (_hasLayout this.outletName) to="before"}}

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
      <DAsyncContent @asyncData={{this.children}}>
        <:loading>
          {{! Resolving async blocks should not display a loading UI }}
        </:loading>

        <:content as |layout|>
          {{! layout is only undefined when no blocks passed validation, in
              which case the :empty block below renders instead }}
          {{#if layout}}
            {{#let
              (component
                BlockOutletRootContainer
                outletName=this.outletName
                outletArgs=this.outletArgsWithDeprecations
                rawChildren=layout.rawChildren
                showGhosts=layout.showGhosts
                showVisualOverlay=layout.showVisualOverlay
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
          {{/if}}
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
      </DAsyncContent>
    {{/let}}

    {{! yield to :after block with hasLayout boolean for conditional rendering
        This allows block outlets to wrap other elements and conditionally render them based on
        the presence of a registered layout if necessary }}
    {{yield (_hasLayout this.outletName) to="after"}}
  </template>
}

registerRootBlock(BlockOutlet);
