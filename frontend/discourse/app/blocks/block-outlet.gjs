// @ts-check
/**
 * BlockOutlet System
 *
 * This module provides the BlockOutlet component and outlet layout management.
 * BlockOutlet is the root entry point for rendering blocks in designated areas.
 *
 * This file handles:
 * - BlockOutlet component
 * - Outlet layout registration and management via a three-layer resolution chain
 * - Child block creation and rendering
 */
import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { cached } from "@glimmer/tracking";
import { untrack } from "@glimmer/validator";
import {
  trackedArray,
  trackedMap,
  trackedObject,
} from "@ember/reactive/collections";
import curryComponent from "ember-curry-component";
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
  registerRootBlock,
} from "discourse/lib/blocks/-internals/decorator";
import {
  captureCallSite,
  raiseBlockError,
} from "discourse/lib/blocks/-internals/error";
import {
  _registerLayoutBlockIfNeeded,
  isBlockRegistryFrozen,
} from "discourse/lib/blocks/-internals/registry/block";
import { applyArgDefaults } from "discourse/lib/blocks/-internals/utils";
import { validateLayout } from "discourse/lib/blocks/-internals/validation/layout";
import { isRailsTesting, isTesting } from "discourse/lib/environment";
import { buildArgsWithDeprecations } from "discourse/lib/outlet-args";
import { BLOCK_OUTLETS } from "discourse/lib/registry/block-outlets";
/** @type {import("discourse/ui-kit/d-async-content.gjs")} */
import DAsyncContent from "discourse/ui-kit/d-async-content";

/**
 * A block entry in a layout configuration.
 *
 * @typedef {Object} LayoutEntry
 * @property {typeof Component | string} block - The block component class (must use @block decorator) or a registered block name string.
 * @property {Object} [args] - Args to pass to the block component.
 * @property {string|string[]} [classNames] - Additional CSS classes for the block wrapper.
 * @property {Array<LayoutEntry>} [children] - Nested block entries (only for container blocks).
 * @property {Array<Object>|Object} [conditions] - Conditions that must pass for block to render.
 * @property {Object} [containerArgs] - Args passed from parent container's childArgs.
 */

/**
 * @typedef {Object} LayerEntry
 * @property {Promise<Array<LayoutEntry>>} validatedLayout - Promise resolving to the validated layout array.
 * @property {Array<LayoutEntry>} layout - The raw layout array (synchronously accessible).
 * @property {number} [themeId] - The theme id (only set on entries in the "theme" layer).
 */

/**
 * @typedef {Object} PerOutletRecord
 * @property {LayerEntry|undefined} session-draft - The editor's in-memory draft (highest precedence).
 * @property {LayerEntry[]} theme - One entry per theme in the active stack, ordered by stack position. Last in array wins.
 * @property {LayerEntry|undefined} code-default - The layout registered via api.renderBlocks (lowest precedence).
 */

/**
 * Layer names for the layout resolution chain. Listed from highest precedence
 * to lowest. Within the "theme" layer, ordering follows the theme stack — the
 * last theme to register a layout for an outlet wins.
 *
 * Layers exist for editor support and theme integration:
 * - "session-draft": the visual editor's in-memory edits, scoped to the
 *   current session. Cleared on exit, save, or discard.
 * - "theme": layouts shipped by themes via `block_layout` ThemeFields. Hydrated
 *   at boot from the active theme stack.
 * - "code-default": the existing `api.renderBlocks(...)` registration path.
 *   What plugins / core ship as the default layout for an outlet.
 */
export const LAYOUT_LAYERS = Object.freeze({
  SESSION_DRAFT: "session-draft",
  THEME: "theme",
  CODE_DEFAULT: "code-default",
});

const LAYER_VALUES = Object.values(LAYOUT_LAYERS);

/**
 * Maps outlet names to their per-layer record. Each outlet can hold one entry
 * per layer; resolution walks the layers in precedence order and returns the
 * highest-priority entry that has been set.
 *
 * Stored as a `trackedMap` so that mutations (a layer being set or cleared)
 * trigger `BlockOutlet#validatedLayout` to re-evaluate, causing the affected
 * outlet to re-render with the newly-resolved layout.
 *
 * Per-outlet records are themselves replaced wholesale on every mutation
 * (immutable updates) so the trackedMap's `set` notification fires reliably.
 *
 * DO NOT EXPORT THIS MAP to prevent layouts bypassing the validation steps.
 *
 * @type {Map<string, PerOutletRecord>}
 */
const outletLayouts = trackedMap();

/**
 * Counter for generating stable entry keys.
 * Incremented for each block entry that doesn't already carry a `__stableKey`,
 * either at first registration or for newly-inserted entries during editor-
 * driven layer publishes.
 *
 * @type {number}
 */
let nextEntryKey = 0;

/**
 * WeakSet of entry args objects we've already wrapped in `trackedObject`,
 * used to avoid double-wrapping when `assignStableKeys` re-runs over a layout
 * that's already been registered once (for example when a theme layer is
 * republished via MessageBus, or when a session-draft layout is re-emitted
 * by the editor).
 *
 * @type {WeakSet<Object>}
 */
const _trackedArgsCache = new WeakSet();

/**
 * Companion to `_trackedArgsCache` for the entry shell itself. Lets us
 * recognise wrapped entries on re-entry into `assignStableKeys` (re-publish,
 * draft clone) so we don't wrap-the-wrap.
 *
 * @type {WeakSet<Object>}
 */
const _trackedEntryCache = new WeakSet();

/**
 * Recursively assigns stable keys to all block entries in a layout, and
 * wraps each entry's `args` in a `trackedObject` so editor-driven mutations
 * (e.g. `entry.args.title = "new"`) propagate reactively through the
 * compute-ref proxy created by `curryComponent` to the rendered block —
 * no layout swap or component re-curry needed.
 *
 * Each entry receives a `__stableKey` property that remains constant across
 * renders. This is critical for Ember's `{{#each key=}}` to maintain DOM
 * identity when blocks are hidden/shown by conditions, and for the visual
 * editor to correlate canvas selections with outline rows across mutations.
 *
 * Keys are assigned at registration time rather than render time, ensuring
 * they survive the shallow cloning in `BlockOutletRootContainer#preprocessEntries`.
 *
 * @param {Array<LayoutEntry>} entries - The block entries to process.
 * @param {Object} [options]
 * @param {boolean} [options.skipExisting=false] - When true, entries that
 *   already have a `__stableKey` are left alone. Used by layer-publishing
 *   helpers so editor-driven replacements preserve the identity of unchanged
 *   entries (selection, DOM identity, render cache).
 */
function assignStableKeys(entries, { skipExisting = false } = {}) {
  for (let i = 0; i < entries.length; i++) {
    const entry = entries[i];
    if (!skipExisting || entry.__stableKey === undefined) {
      entry.__stableKey = nextEntryKey++;
    }

    // Auto-register class refs by their decorator-assigned name so the
    // saved layout's string references resolve on reload. Themes that
    // pass class refs to `api.renderBlocks` typically don't bother with
    // an explicit `api.registerBlock(...)` — the class works fine as a
    // direct render-time reference. But the visual editor saves layouts
    // as JSON (string refs only), so the next page load tries to resolve
    // those strings via the registry. Without this auto-register, every
    // theme block reachable through a layout edit would 404 on reload.
    if (typeof entry.block === "function") {
      _registerLayoutBlockIfNeeded(entry.block);
    }

    if (entry.args && !_trackedArgsCache.has(entry.args)) {
      const initialArgs = { ...entry.args };
      const wrapped = trackedObject(initialArgs);
      _trackedArgsCache.add(wrapped);
      entry.args = wrapped;
      // Snapshot the initial set of arg keys at wrap time. Consumers like
      // `createBlockArgsWithReactiveGetters` need to enumerate the keys, but
      // calling `Object.keys(entry.args)` (or anything that triggers the
      // Proxy's `ownKeys` trap) would consume `trackedObject`'s collection
      // tag — which is dirtied on every set, not just on add/delete. That
      // would invalidate `BlockOutletRootContainer.processedChildren`
      // (which builds curries inside its tracked computation) on every
      // edit, forcing every container to re-curry even though the keys
      // haven't actually changed. Caching the keys here lets consumers
      // read them without ever opening the collection-tag dep.
      entry.__argKeys = Object.keys(initialArgs);
    }

    // Same reactivity treatment for `containerArgs` (values the parent
    // container reads from its `@children`). Without this, a mutation
    // like `entry.containerArgs.column = "3"` wouldn't propagate to the
    // parent's render — the parent's template reads `child.containerArgs.X`
    // and needs a tracked Proxy to register a per-key dep at render time.
    if (entry.containerArgs && !_trackedArgsCache.has(entry.containerArgs)) {
      const initialContainerArgs = { ...entry.containerArgs };
      const wrapped = trackedObject(initialContainerArgs);
      _trackedArgsCache.add(wrapped);
      entry.containerArgs = wrapped;
      entry.__containerArgKeys = Object.keys(initialContainerArgs);
    }

    // Wrap the entry shell itself so writes to its top-level fields
    // (`__failureType`, `__failureReason`, `__visible`, `children`,
    // `conditions`, …) participate in autotracking. The validator stamps
    // soft-failure fields directly on the entry; clearing them via
    // `clearValidatorStamps` would otherwise be invisible to Glimmer
    // and the editor's banner / outline / per-block ghost chrome would
    // keep showing a stale error after the author has fixed it.
    //
    // Unlike `args` / `containerArgs`, we don't snapshot an entry-level
    // key list: no live consumer iterates the entry as a whole (the only
    // `Object.keys(entry)` call sits in core's pre-registration validator
    // path), so there's no collection-tag dep to defend against.
    if (!_trackedEntryCache.has(entry)) {
      const wrapped = trackedObject(entry);
      _trackedEntryCache.add(wrapped);
      entries[i] = wrapped;
      if (wrapped.children?.length) {
        assignStableKeys(wrapped.children, { skipExisting });
      }
    } else if (entry.children?.length) {
      assignStableKeys(entry.children, { skipExisting });
    }
  }
}

/**
 * Builds an empty per-outlet record. All layers start unset.
 *
 * @returns {PerOutletRecord}
 */
function makeEmptyRecord() {
  return {
    [LAYOUT_LAYERS.SESSION_DRAFT]: undefined,
    [LAYOUT_LAYERS.THEME]: [],
    [LAYOUT_LAYERS.CODE_DEFAULT]: undefined,
  };
}

/**
 * Returns true when a per-outlet record has no entries at any layer.
 *
 * @param {PerOutletRecord} record
 * @returns {boolean}
 */
function isRecordEmpty(record) {
  return (
    !record[LAYOUT_LAYERS.SESSION_DRAFT] &&
    record[LAYOUT_LAYERS.THEME].length === 0 &&
    !record[LAYOUT_LAYERS.CODE_DEFAULT]
  );
}

/**
 * Walks the layers of a per-outlet record in precedence order and returns the
 * first entry that has been set. Within the "theme" layer, the last entry in
 * the stack wins (matching the existing theme-stack precedence rule).
 *
 * Reads from the trackedMap inside this function are tracked by Ember's
 * autotracking — callers that read through here re-run when any layer in the
 * record changes.
 *
 * @param {string} outletName
 * @returns {LayerEntry|undefined}
 */
function resolveLayoutRecord(outletName) {
  const layers = outletLayouts.get(outletName);
  if (!layers) {
    return undefined;
  }
  if (layers[LAYOUT_LAYERS.SESSION_DRAFT]) {
    return layers[LAYOUT_LAYERS.SESSION_DRAFT];
  }
  const themeLayer = layers[LAYOUT_LAYERS.THEME];
  if (themeLayer.length > 0) {
    return themeLayer[themeLayer.length - 1];
  }
  if (layers[LAYOUT_LAYERS.CODE_DEFAULT]) {
    return layers[LAYOUT_LAYERS.CODE_DEFAULT];
  }
  return undefined;
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
 * Returns a Map of outlet names to their currently-resolved layout entry.
 * Snapshots the resolution at call time — consumers that need reactivity
 * should call this from a tracked context.
 *
 * USE ONLY FOR TESTING PURPOSES.
 *
 * @returns {Map<string, LayerEntry>} The resolved outlet entries.
 */
export function _getOutletLayouts() {
  if (!DEBUG) {
    return new Map();
  }
  /** @type {Map<string, LayerEntry>} */
  const resolved = new Map();
  for (const outletName of outletLayouts.keys()) {
    const entry = resolveLayoutRecord(outletName);
    if (entry) {
      resolved.set(outletName, entry);
    }
  }
  return resolved;
}

/**
 * Returns the raw per-outlet records (full layer state) for introspection.
 * Used by the visual editor to detect whether a session-draft already exists
 * for an outlet without having to track that bookkeeping itself.
 *
 * @internal
 * @returns {Map<string, PerOutletRecord>}
 */
export function _getRawOutletLayouts() {
  if (!DEBUG) {
    return new Map();
  }
  return outletLayouts;
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
  const { block: ComponentClass, containerArgs, classNames, id } = entry;
  const blockMeta = getBlockMetadata(ComponentClass);
  const isContainer = blockMeta?.isContainer ?? false;

  // Build the block's args via reactive getters that read directly from
  // `entry.args` (a `trackedObject` after registration). Mutations to
  // `entry.args` then propagate to the rendered block automatically — the
  // visual editor relies on this for live arg editing.
  const blockArgs = createBlockArgsWithReactiveGetters(entry, ComponentClass, {
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

  // For decorator-driven className resolution we still need a snapshot of
  // current args (a function-form `classNames(args)` shouldn't have to
  // navigate `trackedObject` itself). Run inside `untrack` so the spread
  // inside `applyArgDefaults` doesn't open tracked deps on the entry's
  // `trackedObject` collection / per-key tags from this render context —
  // those deps would invalidate the parent `processedChildren` getter on
  // every keystroke, forcing every container to re-curry. Lazy reactive
  // reads still happen via the curry's compute-ref proxy at render time;
  // the snapshot here is intentionally a one-shot read.
  const argsSnapshot = untrack(() =>
    applyArgDefaults(ComponentClass, entry.args ?? {})
  );

  // All blocks are wrapped for consistent styling. Parent containers can
  // augment the curried invocation with `@style` (e.g. CSS Grid placement)
  // — the wrapper applies whatever the parent passes without itself
  // knowing about layout modes.
  let wrappedComponent = wrapBlockLayout(
    {
      name: blockMeta?.blockName,
      namespace: blockMeta?.namespace,
      outletName: debugContext.outletName,
      isContainer,
      id,
      decoratorClassNames: resolveDecoratorClassNames(blockMeta, argsSnapshot),
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
        // The composite stable key for this entry (`${blockName}:${__stableKey}`),
        // minted in entry-processing.js. Exposed here so debug consumers can
        // correlate a rendered block back to its layout entry without inventing
        // their own identifier.
        key: debugContext.key,
        Component: wrappedComponent,
        args: argsSnapshot,
        containerArgs,
        conditions: debugContext.conditions,
        conditionsPassed: true,
      },
      {
        // `outletName` here is historically the rendered block's display
        // hierarchy (e.g. `"homepage-blocks/section-1(#hero)"`) — that's
        // what dev-tools' overlay surfaces as a block's location. Kept
        // unchanged for backward compatibility.
        outletName: debugContext.displayHierarchy,
        // The real, registry-level outlet that owns this entry (the same
        // string the block layer was registered against). Consumers that
        // need to address the layout — like the visual editor's
        // `moveBlock` — read this; the `outletName` field above is the
        // human-readable hierarchy and won't match the registry for
        // nested blocks.
        rootOutletName: debugContext.outletName,
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
          id,
          args: argsSnapshot,
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
 * Builds a layer entry whose `validatedLayout` is a memoized lazy getter —
 * validation only kicks off the first time someone reads the property,
 * and every subsequent read returns the same Promise. This lets callers
 * choose between eager validation (read immediately, e.g. tests, the
 * `api.renderBlocks` path) and lazy validation (don't read at publish
 * time, let `BlockOutlet`'s render path trigger it later).
 *
 * Lazy validation matters for the boot-time theme hydration: layouts
 * loaded from `block_layout` ThemeFields reference blocks by string
 * name. Validation has to look those names up in the block registry. If
 * we trigger validation at hydration time, we race theme api-initializers
 * that register blocks by side-effect of calling `api.renderBlocks(class-
 * ref)`. Deferring validation until `BlockOutlet` first reads
 * `validatedLayout` (which happens at render time, after every
 * initializer has settled) sidesteps the race entirely.
 */
function createLayerEntry({
  layout,
  outletName,
  blocksService,
  callSiteError,
  themeId,
  permissive = false,
}) {
  /** @type {Promise<Array<LayoutEntry>>|null} */
  let validationPromise = null;
  /** @type {LayerEntry} */
  // @ts-expect-error - validatedLayout is defined below via defineProperty.
  // `validationWarnings` is `trackedArray` so consumers (the visual editor's
  // toolbar tally, future inspector banners) re-render when validation
  // completes async — without it the array would mutate after the toolbar
  // has already evaluated, leaving stale "0 warnings" until the next
  // structural change.
  const entry = { layout, validationWarnings: trackedArray() };
  if (themeId !== undefined) {
    entry.themeId = themeId;
  }
  Object.defineProperty(entry, "validatedLayout", {
    get() {
      if (!validationPromise) {
        if (permissive) {
          // Per-entry isolation: validateLayout's per-entry try/catch
          // marks each failing entry with `__failureType` /
          // `__failureReason` and continues to the next entry. The
          // collected messages land on `entry.validationWarnings`
          // (trackedArray, so the editor's toolbar / inspector update
          // reactively when validation resolves async).
          const validationContext = {
            seenIds: new Map(),
            permissive: true,
            warnings: [],
          };
          validationPromise = validateLayout(
            layout,
            outletName,
            blocksService,
            "",
            callSiteError,
            null,
            null,
            null,
            0,
            validationContext
          ).then(() => {
            for (const w of validationContext.warnings) {
              entry.validationWarnings.push(w);
            }
            return layout;
          });
        } else {
          validationPromise = validateLayout(
            layout,
            outletName,
            blocksService,
            "",
            callSiteError
          ).then(() => layout);
        }
      }
      return validationPromise;
    },
    enumerable: true,
  });
  return entry;
}

/**
 * Sets the layout for one specific layer of an outlet. Used internally by
 * `_renderBlocks` (the existing `code-default` registration path), the theme-
 * load initializer (the `theme` layer), and the visual editor (the
 * `session-draft` layer).
 *
 * The per-outlet record is replaced wholesale (immutable update) so the
 * trackedMap notifies subscribers reliably. Stable keys on the supplied
 * layout are preserved (`skipExisting: true`); newly-introduced entries
 * receive fresh keys.
 *
 * Validation is memoized lazily on the layer entry. By default
 * (`options.lazy` falsy), this function reads the entry's
 * `validatedLayout` before returning it — which kicks off validation
 * eagerly, matching the historical behavior of `api.renderBlocks` and
 * the test suite. Pass `options.lazy: true` to skip the eager read; the
 * Promise then only materialises when `BlockOutlet` first reads the
 * entry at render time (used by boot-time theme hydration to avoid
 * racing theme api-initializers that register blocks).
 *
 * @internal Not part of the public plugin API. Use `api.setLayoutLayer` from
 *   plugin code.
 *
 * @param {string} outletName
 * @param {string} layer - One of `LAYOUT_LAYERS`.
 * @param {Array<LayoutEntry>} layout
 * @param {import("@ember/owner").default} [owner]
 * @param {Object} [options]
 * @param {number} [options.themeId] - Required when layer is "theme".
 * @param {boolean} [options.lazy=false] - When true, defers validation
 *   until the entry's `validatedLayout` is first read (typically by
 *   `BlockOutlet` at render time).
 * @param {boolean} [options.permissive=false] - When true, validation
 *   errors don't reject the `validatedLayout` promise. Instead the error
 *   is captured on the layer entry's `validationWarnings` and the layout
 *   is returned as-is. Used by the visual editor's `session-draft` layer
 *   so legitimate mid-edit invalid states (empty container after a drag,
 *   typo in a block name, etc.) don't crash the page. Code-default and
 *   theme layers are not permissive — they represent committed state
 *   that should be valid; a failure there really is a malformed install.
 * @param {Error|null} [options.callSiteError]
 * @returns {Promise<Array<LayoutEntry>>|undefined} The validated layout
 *   promise (eager mode) or `undefined` (lazy mode).
 * @throws {Error} If validation fails (in strict mode) or the layer /
 *   outlet is unknown.
 */
export function _setLayoutLayer(
  outletName,
  layer,
  layout,
  owner,
  options = {}
) {
  if (!BLOCK_OUTLETS.includes(outletName)) {
    raiseBlockError(`Unknown block outlet: ${outletName}`);
  }
  if (!LAYER_VALUES.includes(layer)) {
    raiseBlockError(
      `Unknown layout layer: "${layer}". Valid layers are: ${LAYER_VALUES.map((l) => `"${l}"`).join(", ")}.`
    );
  }
  if (layer === LAYOUT_LAYERS.THEME && options.themeId == null) {
    raiseBlockError(
      `setLayoutLayer requires options.themeId when layer is "theme".`
    );
  }
  if (!isBlockRegistryFrozen()) {
    raiseBlockError(
      `_setLayoutLayer() was called before the block registry was frozen. ` +
        `Move your code to an initializer that runs after "freeze-block-registry". ` +
        `Outlet: "${outletName}", layer: "${layer}".`
    );
  }

  const callSiteError =
    options.callSiteError ?? captureCallSite(_setLayoutLayer);
  const blocksService = owner?.lookup("service:blocks");

  // Mint stable keys; preserve any that already exist so editor-driven
  // republishes don't tear down DOM identity for unchanged entries.
  assignStableKeys(layout, { skipExisting: true });

  const layerEntry = createLayerEntry({
    layout,
    outletName,
    blocksService,
    callSiteError,
    themeId: layer === LAYOUT_LAYERS.THEME ? options.themeId : undefined,
    permissive: options.permissive ?? false,
  });

  const existing = outletLayouts.get(outletName) ?? makeEmptyRecord();
  let nextRecord;
  if (layer === LAYOUT_LAYERS.THEME) {
    // Replace the entry for this themeId (if present) or append. Order is
    // governed by call order — callers (the theme-load initializer) should
    // register layers in theme-stack order.
    const themes = existing[LAYOUT_LAYERS.THEME];
    const idx = themes.findIndex((t) => t.themeId === options.themeId);
    const newThemes =
      idx >= 0
        ? [...themes.slice(0, idx), layerEntry, ...themes.slice(idx + 1)]
        : [...themes, layerEntry];
    nextRecord = { ...existing, [LAYOUT_LAYERS.THEME]: newThemes };
  } else {
    nextRecord = { ...existing, [layer]: layerEntry };
  }

  outletLayouts.set(outletName, nextRecord);

  if (options.lazy) {
    return undefined;
  }
  return layerEntry.validatedLayout;
}

/**
 * Clears one layer's entry for an outlet. For the "theme" layer, an
 * `options.themeId` targets a specific theme; omitting it clears all themes
 * for the outlet.
 *
 * If clearing leaves the outlet with no entries at any layer, the outlet's
 * record is removed entirely from the map (so `_hasLayout` returns false).
 *
 * @internal
 *
 * @param {string} outletName
 * @param {string} layer
 * @param {Object} [options]
 * @param {number} [options.themeId]
 */
export function _clearLayoutLayer(outletName, layer, options = {}) {
  if (!LAYER_VALUES.includes(layer)) {
    raiseBlockError(`Unknown layout layer: "${layer}".`);
  }
  const existing = outletLayouts.get(outletName);
  if (!existing) {
    return;
  }

  let nextRecord;
  if (layer === LAYOUT_LAYERS.THEME) {
    if (options.themeId == null) {
      nextRecord = { ...existing, [LAYOUT_LAYERS.THEME]: [] };
    } else {
      nextRecord = {
        ...existing,
        [LAYOUT_LAYERS.THEME]: existing[LAYOUT_LAYERS.THEME].filter(
          (t) => t.themeId !== options.themeId
        ),
      };
    }
  } else {
    nextRecord = { ...existing, [layer]: undefined };
  }

  if (isRecordEmpty(nextRecord)) {
    outletLayouts.delete(outletName);
  } else {
    outletLayouts.set(outletName, nextRecord);
  }
}

/**
 * Registers an outlet layout (array of block entries) for a named outlet.
 *
 * This is the main entry point for plugins to render blocks in designated areas.
 * Each outlet can only have one `code-default` layout. Theme and editor draft
 * layouts go through `_setLayoutLayer` instead.
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
 * @throws {Error} If validation fails or the outlet already has a code-default layout.
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
export function _renderBlocks(outletName, layout, owner, callSiteError = null) {
  if (!callSiteError) {
    callSiteError = captureCallSite(_renderBlocks);
  }

  // The "already has a layout" guard fires only when something has already
  // registered on the code-default layer for this outlet. Theme and session-
  // draft layers don't trip it — re-registering theme layouts (via MessageBus)
  // and session drafts (via the editor) is expected and supported.
  const existing = outletLayouts.get(outletName);
  if (existing?.[LAYOUT_LAYERS.CODE_DEFAULT]) {
    raiseBlockError(
      `Block outlet "${outletName}" already has a layout registered.`
    );
  }

  return _setLayoutLayer(
    outletName,
    LAYOUT_LAYERS.CODE_DEFAULT,
    layout,
    owner,
    {
      callSiteError,
    }
  );
}

/**
 * Checks whether any layer has a layout registered for the given outlet.
 *
 * @internal This is an internal API. Use the `blocks` service's `hasLayout()` method instead.
 *
 * @param {string} outletName - The outlet identifier to check.
 * @returns {boolean} True if any layer has a layout for this outlet.
 */
export function _hasLayout(outletName) {
  return resolveLayoutRecord(outletName) !== undefined;
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
@block("block-outlet", { container: true })
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
    return resolveLayoutRecord(this.#name)?.validatedLayout;
  }

  /**
   * Processes block entries and returns renderable components.
   *
   * @returns {Promise<{rawChildren: Array<Object>, showGhosts: boolean, showVisualOverlay: boolean, isLoggingEnabled: boolean}>|undefined}
   */
  @cached
  get children() {
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
   * @returns {typeof Component<{outletName: string, blockCount: number, outletArgs: object, error: Error}>|null}
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
