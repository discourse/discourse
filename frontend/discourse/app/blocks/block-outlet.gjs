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
// @ts-ignore - `@glimmer/validator` is a transitive dependency without
// direct types resolution under our pnpm layout.
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
import { resetBlockData } from "discourse/lib/blocks/-internals/data-coordinator";
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
 * @property {typeof Component | string} block - The block component class (must use the `@block` decorator) or a registered block name string.
 * @property {string} [id] - Unique identifier for BEM styling and targeting.
 * @property {Object} [args] - Args to pass to the block component.
 * @property {string|string[]} [classNames] - Additional CSS classes for the block wrapper.
 * @property {Array<LayoutEntry>} [children] - Nested block entries (only for container blocks).
 * @property {Array<Object>|Object} [conditions] - Conditions that must pass for block to render.
 * @property {Object} [containerArgs] - Args passed from parent container's childArgs.
 * @property {number} [__stableKey] - Stable key minted at registration time so
 *   Ember's `{{#each key=}}` and external tooling can correlate this entry
 *   across re-renders. Assigned by `assignStableKeys`.
 * @property {string[]} [__argKeys] - Snapshot of the initial `args` keys taken
 *   at wrap time. Lets consumers enumerate keys without touching the
 *   `trackedObject` collection tag (which would invalidate on every set).
 * @property {string[]} [__containerArgKeys] - Same as `__argKeys` but for the
 *   `containerArgs` snapshot.
 * @property {string} [__failureType] - Set by the validator when an entry
 *   fails permissively (session-draft layer). Cleared on a successful revalidate.
 * @property {string} [__failureReason] - Human-readable failure message paired
 *   with `__failureType`.
 * @property {boolean} [__visible] - Whether the entry currently passes its
 *   conditions; set by the per-render condition evaluator.
 */

/**
 * @typedef {Object} LayerEntry
 * @property {Promise<Array<LayoutEntry>>} validatedLayout - Promise resolving to the validated layout array.
 * @property {Array<LayoutEntry>} layout - The raw layout array (synchronously accessible).
 * @property {Array<Object>} validationWarnings - Tracked array of warnings collected during permissive validation. Populated asynchronously.
 * @property {number} [themeId] - The theme id (only set on entries in the "theme" layer).
 * @property {string} [source] - Provenance: one of `LAYOUT_SOURCE` (which channel registered this entry).
 * @property {string|number|null} [sourceId] - Opaque source id: the theme id for "theme" entries, or a caller-supplied id (or null) for code / session-draft entries.
 * @property {boolean} [overridable] - Code entries only: true for an editable seed, false for a locked (authoritative) layout.
 * @property {number} [themeStackIndex] - Theme entries only: the theme's position in the active stack (`Theme.transform_ids`); the minimum-ranked theme owns the outlet.
 */

/**
 * @typedef {Object} PerOutletRecord
 * @property {LayerEntry|undefined} session-draft - In-memory layout edits scoped to the current session.
 * @property {LayerEntry[]} theme - One entry per theme in the active stack. The entry with the minimum `themeStackIndex` (the most ancestral theme) owns the outlet.
 * @property {LayerEntry|undefined} code-locked - A locked (non-overridable) layout registered via api.renderBlocks. Authoritative; outranks every other layer.
 * @property {LayerEntry|undefined} code-overridable - An overridable seed registered via api.renderBlocks (lowest precedence).
 */

/**
 * Public layer names for `api.setLayoutLayer` / `api.clearLayoutLayer`. Within
 * the "theme" layer, the theme with the minimum stack rank (the most ancestral
 * theme that ships a layout — parent before components) owns the outlet.
 *
 * - "session-draft": in-memory layout edits scoped to the current session.
 *   Wins over the persisted theme / code layout while editing. Cleared on exit,
 *   save, or discard.
 * - "theme": layouts shipped by themes via `block_layout` ThemeFields. Hydrated
 *   at boot from the active theme stack.
 * - "code-default": the `api.renderBlocks(...)` registration path. Internally
 *   this splits into a locked slot (authoritative; outranks every layer) and an
 *   overridable seed slot (the in-code default; lowest precedence), selected by
 *   the `overridable` flag — but callers still pass the single "code-default"
 *   layer name.
 */
export const LAYOUT_LAYERS = Object.freeze({
  SESSION_DRAFT: "session-draft",
  THEME: "theme",
  CODE_DEFAULT: "code-default",
});

/** @type {string[]} */
const LAYER_VALUES = Object.values(LAYOUT_LAYERS);

/**
 * Provenance source for a resolved layer entry — deliberately distinct from the
 * layer name. The "code" source additionally carries the `overridable` axis
 * (seed vs locked).
 */
export const LAYOUT_SOURCE = Object.freeze({
  SESSION_DRAFT: "session-draft",
  THEME: "theme",
  CODE: "code",
});

/**
 * The default `overridable` stance for code layouts registered via
 * `api.renderBlocks`: `true` ships an editable seed, `overridable: false` ships
 * a locked, authoritative layout. Kept as one constant so the global stance is
 * trivially flippable later.
 */
export const CODE_LAYOUT_OVERRIDABLE_BY_DEFAULT = true;

/*
 * Internal record slots for the two code-layer kinds. The public layer name
 * `LAYOUT_LAYERS.CODE_DEFAULT` is unchanged for `api.setLayoutLayer` /
 * `api.clearLayoutLayer`; `_setLayoutLayer` routes a CODE_DEFAULT write into one
 * of these by the resolved `overridable` flag. They are never passed as a public
 * `layer` argument, so they stay out of `LAYER_VALUES`.
 */
const CODE_LOCKED = "code-locked";
const CODE_OVERRIDABLE = "code-overridable";

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
 * Ref-count of `<BlockOutlet>` instances currently mounted on the page, keyed by
 * outlet name. Populated by `BlockOutlet`'s own lifecycle (constructor /
 * `willDestroy`) at page render — before any consumer that enumerates outlets
 * runs — independent of whether the outlet has a layout. So consumers know which
 * outlets are on the page with no DOM scan and no render-timing race.
 *
 * A plain (UNtracked) Map on purpose: it's mutated during render (component
 * construction), so tracking it would trip a backtracking-rerender assertion the
 * moment a reader touches it in the same render pass. It doesn't need to be
 * tracked — page mounts are stable for the life of a page, and consumers already
 * recompute off the tracked layout layers (`outletLayouts`). Ref-counted so
 * duplicate mounts and teardown-then-remount don't drop a name prematurely.
 *
 * @type {Map<string, number>}
 */
const mountedOutletCounts = new Map();

/**
 * Counter for generating stable entry keys.
 * Incremented for each block entry that doesn't already carry a `__stableKey`,
 * either at first registration or for newly-inserted entries during edit-
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
 * during in-session editing).
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
 * wraps each entry's `args` in a `trackedObject` so edit-driven mutations
 * (e.g. `entry.args.title = "new"`) propagate reactively through the
 * compute-ref proxy created by `curryComponent` to the rendered block —
 * no layout swap or component re-curry needed.
 *
 * Each entry receives a `__stableKey` property that remains constant across
 * renders. This is critical for Ember's `{{#each key=}}` to maintain DOM
 * identity when blocks are hidden/shown by conditions, and for external
 * tooling to correlate rendered blocks with their layout entries across
 * mutations.
 *
 * Keys are assigned at registration time rather than render time, ensuring
 * they survive the shallow cloning in `BlockOutletRootContainer#preprocessEntries`.
 *
 * @param {Array<LayoutEntry>} entries - The block entries to process.
 * @param {Object} [options]
 * @param {boolean} [options.skipExisting=false] - When true, entries that
 *   already have a `__stableKey` are left alone. Used by layer-publishing
 *   helpers so edit-driven replacements preserve the identity of unchanged
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
    // direct render-time reference. But a persisted layout is saved as
    // JSON (string refs only), so the next page load tries to resolve
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
    // and anything that reads those fields would keep showing a stale
    // error after it has been fixed.
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
    [CODE_LOCKED]: undefined,
    [CODE_OVERRIDABLE]: undefined,
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
    !record[CODE_LOCKED] &&
    !record[CODE_OVERRIDABLE]
  );
}

/**
 * Walks the layers of a per-outlet record in precedence order and returns the
 * first entry that wins:
 *
 *   1. a locked code layout (`overridable: false`) — authoritative;
 *   2. the session draft — live editing;
 *   3. the owner theme — the theme entry with the MINIMUM `themeStackIndex` (the
 *      most ancestral theme that ships a layout, parent before components);
 *   4. an overridable code seed — the in-code default.
 *
 * Reads from the trackedMap inside this function are tracked by Ember's
 * autotracking — callers that read through here re-run when any layer in the
 * record changes. The owner loop iterates a plain array stored on the record, so
 * it adds no tracking beyond the single `outletLayouts.get` read.
 *
 * @param {string} outletName
 * @returns {LayerEntry|undefined}
 */
function resolveLayoutRecord(outletName, { ignoreSessionDraft = false } = {}) {
  const layers = outletLayouts.get(outletName);
  if (!layers) {
    return undefined;
  }
  // 1. A locked programmatic layout is authoritative.
  if (layers[CODE_LOCKED]) {
    return layers[CODE_LOCKED];
  }
  // 2. A live session draft wins while editing. Callers that need the
  //    underlying (pre-edit) source instead pass `ignoreSessionDraft` to skip
  //    this layer and resolve the layer that owns the outlet apart from the
  //    in-session edit.
  if (!ignoreSessionDraft && layers[LAYOUT_LAYERS.SESSION_DRAFT]) {
    return layers[LAYOUT_LAYERS.SESSION_DRAFT];
  }
  // 3. The owner theme is the entry with the MAXIMUM stack rank — the
  //    most-derived theme in the active stack (`Theme.transform_ids` orders the
  //    parent first, then its components), so a component overrides the layout
  //    of the theme it is installed on. Strictly-greater comparison keeps the
  //    first entry at the maximum rank (one entry per theme id, so ties don't
  //    occur in practice). An entry with no known rank defaults to the lowest
  //    priority so it never spuriously beats a properly-ranked entry.
  let owner;
  let ownerRank = -Infinity;
  for (const entry of layers[LAYOUT_LAYERS.THEME]) {
    const rank = entry.themeStackIndex ?? -1;
    if (rank > ownerRank) {
      ownerRank = rank;
      owner = entry;
    }
  }
  if (owner) {
    return owner;
  }
  // 4. An overridable programmatic seed is the in-code default.
  if (layers[CODE_OVERRIDABLE]) {
    return layers[CODE_OVERRIDABLE];
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
    mountedOutletCounts.clear();
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
 * Used by callers that need to detect whether a session-draft already exists
 * for an outlet without having to track that bookkeeping themselves.
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
  // `entry.args` then propagate to the rendered block automatically, which
  // is what powers live arg editing.
  //
  // A container's `@children` is sourced from a tracked holder
  // (`childrenHolder`) rather than a captured array, so a cached (persisted)
  // container instance observes freshly processed children on later renders
  // without being re-curried. The getter reads the holder's single tracked
  // key — enough for the curry's compute-ref to re-pull, but it never opens
  // the holder's collection tag. Non-containers have no holder and fall back
  // to the static (undefined) children value.
  const childrenHolder = debugContext.childrenHolder;
  const blockArgs = createBlockArgsWithReactiveGetters(entry, ComponentClass, {
    children: childrenHolder
      ? () => childrenHolder.current
      : debugContext.processedChildren,
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
      // When the block declares a data dependency, hand the wrapper its `data`
      // declaration plus the reactive args object so the wrapper can derive the
      // request descriptor and resolve it (the wrapper renders after the sync
      // pipeline, so this never touches the outlet's synchronous getter).
      dataMeta: blockMeta?.data ?? null,
      dataArgs: blockMeta?.data ? blockArgs : null,
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
        // need to address the layout — e.g. a `moveBlock` operation —
        // read this; the `outletName` field above is the human-readable
        // hierarchy and won't match the registry for nested blocks.
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
  source,
  sourceId = null,
  overridable,
  themeStackIndex,
}) {
  /** @type {Promise<Array<LayoutEntry>>|null} */
  let validationPromise = null;
  /** @type {LayerEntry} */
  // @ts-expect-error - validatedLayout is defined below via defineProperty.
  // `validationWarnings` is `trackedArray` so consumers re-render when
  // validation completes async — without it the array would mutate after
  // a consumer has already read it, leaving a stale count until the next
  // structural change.
  const entry = { layout, validationWarnings: trackedArray() };
  if (themeId !== undefined) {
    entry.themeId = themeId;
  }
  // Provenance, stamped once at creation as plain own-properties (read directly
  // in resolveLayoutRecord, zero per-render cost). The flag and stack rank are
  // stored on the entry — not a side Set — so the wholesale record replacement
  // keeps them autotracked, the same way `themeId` above is.
  if (source !== undefined) {
    entry.source = source;
    entry.sourceId = sourceId;
  }
  if (overridable !== undefined) {
    entry.overridable = overridable;
  }
  if (themeStackIndex !== undefined) {
    entry.themeStackIndex = themeStackIndex;
  }
  Object.defineProperty(entry, "validatedLayout", {
    get() {
      if (!validationPromise) {
        if (permissive) {
          // Per-entry isolation: validateLayout's per-entry try/catch
          // marks each failing entry with `__failureType` /
          // `__failureReason` and continues to the next entry. The
          // collected messages land on `entry.validationWarnings`
          // (trackedArray, so consumers update reactively when validation
          // resolves async).
          //
          // `collect: true` opts into per-entry arg accumulation — every
          // failing arg surfaces at once instead of having to fix one,
          // re-validate, see the next ("whack-a-mole"). Strict
          // mode (`api.renderBlocks` callers) doesn't set this flag and
          // keeps the original fail-fast behaviour.
          const validationContext = {
            seenIds: new Map(),
            permissive: true,
            collect: true,
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
 * load initializer (the `theme` layer), and in-session editing (the
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
 * @param {number} [options.themeStackIndex] - Theme layer: the theme's rank in
 *   the active stack (`Theme.transform_ids`); the minimum-ranked theme owns the
 *   outlet. Preserved from the existing entry on a same-themeId re-registration
 *   when omitted.
 * @param {boolean} [options.overridable] - Code-default layer: `true` (the
 *   default, see `CODE_LAYOUT_OVERRIDABLE_BY_DEFAULT`) writes the overridable
 *   seed slot; `false` writes the locked slot.
 * @param {string|number|null} [options.sourceId] - Code-default layer: an opaque
 *   id for the registering source, recorded as provenance.
 * @param {boolean} [options.lazy=false] - When true, defers validation
 *   until the entry's `validatedLayout` is first read (typically by
 *   `BlockOutlet` at render time).
 * @param {boolean} [options.permissive=false] - When true, validation
 *   errors don't reject the `validatedLayout` promise. Instead the error
 *   is captured on the layer entry's `validationWarnings` and the layout
 *   is returned as-is. Used by the `session-draft` layer
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

  // Mint stable keys; preserve any that already exist so edit-driven
  // republishes don't tear down DOM identity for unchanged entries.
  assignStableKeys(layout, { skipExisting: true });

  const existing = outletLayouts.get(outletName) ?? makeEmptyRecord();

  // Resolve provenance per layer. On a theme re-registration we keep the
  // originally-stamped stack rank when the caller omits one, so a later
  // MessageBus update can't silently change ownership.
  let source;
  let sourceId = null;
  let overridable;
  let themeStackIndex;
  if (layer === LAYOUT_LAYERS.SESSION_DRAFT) {
    source = LAYOUT_SOURCE.SESSION_DRAFT;
  } else if (layer === LAYOUT_LAYERS.THEME) {
    source = LAYOUT_SOURCE.THEME;
    sourceId = options.themeId;
    const existingTheme = existing[LAYOUT_LAYERS.THEME].find(
      (t) => t.themeId === options.themeId
    );
    themeStackIndex = options.themeStackIndex ?? existingTheme?.themeStackIndex;
  } else {
    source = LAYOUT_SOURCE.CODE;
    sourceId = options.sourceId ?? null;
    overridable = options.overridable ?? CODE_LAYOUT_OVERRIDABLE_BY_DEFAULT;
  }

  const layerEntry = createLayerEntry({
    layout,
    outletName,
    blocksService,
    callSiteError,
    themeId: layer === LAYOUT_LAYERS.THEME ? options.themeId : undefined,
    permissive: options.permissive ?? false,
    source,
    sourceId,
    overridable,
    themeStackIndex,
  });

  let nextRecord;
  if (layer === LAYOUT_LAYERS.THEME) {
    // Replace the entry for this themeId (if present) or append. Resolution no
    // longer depends on array order — ownership is the minimum themeStackIndex.
    const themes = existing[LAYOUT_LAYERS.THEME];
    const idx = themes.findIndex((t) => t.themeId === options.themeId);
    const newThemes =
      idx >= 0
        ? [...themes.slice(0, idx), layerEntry, ...themes.slice(idx + 1)]
        : [...themes, layerEntry];
    nextRecord = { ...existing, [LAYOUT_LAYERS.THEME]: newThemes };
  } else if (layer === LAYOUT_LAYERS.CODE_DEFAULT) {
    // The public "code-default" layer maps to one of the two internal slots,
    // selected by the resolved `overridable` flag.
    const slot = overridable ? CODE_OVERRIDABLE : CODE_LOCKED;
    nextRecord = { ...existing, [slot]: layerEntry };
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
  } else if (layer === LAYOUT_LAYERS.CODE_DEFAULT) {
    // Clearing the public "code-default" layer removes BOTH internal slots —
    // the locked layout and the overridable seed — matching the old single-slot
    // semantics.
    nextRecord = {
      ...existing,
      [CODE_LOCKED]: undefined,
      [CODE_OVERRIDABLE]: undefined,
    };
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
 * Formats the trailing ` (sources: …)` clause for a code-layer collision error,
 * naming whichever of the two source ids are known.
 *
 * @param {string|number|null} existingId - The sourceId stamped on the existing entry.
 * @param {string|number|null} incomingId - The sourceId of the colliding registration.
 * @returns {string} A ` (sources: a, b)` suffix, or "" when neither id is known.
 */
function describeCodeSources(existingId, incomingId) {
  const ids = [existingId, incomingId].filter((id) => id != null);
  return ids.length ? ` (sources: ${ids.join(", ")})` : "";
}

/**
 * Registers an outlet layout (array of block entries) for a named outlet.
 *
 * This is the main entry point for plugins and themes to render blocks in
 * designated areas. By default the layout is an editable seed
 * (`overridable: true`); pass `overridable: false` to ship a locked,
 * authoritative layout. The flag — not the caller — decides, so theme JS and
 * plugins share the same path. Theme and session-draft layouts go through
 * `_setLayoutLayer` instead.
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 *
 * @param {string} outletName - The outlet identifier (must be in BLOCK_OUTLETS).
 * @param {Array<LayoutEntry>} layout - Array of block entries.
 * @param {Object} [owner] - The application owner for service lookup (passed from plugin API).
 * @param {Object} [options] - Registration options.
 * @param {boolean} [options.overridable=true] - `true` registers an editable seed; `false` registers a locked, authoritative layout.
 * @param {string|number|null} [options.sourceId] - An opaque id for the registering source, recorded as provenance.
 * @param {Error|null} [options.callSiteError] - Pre-captured error for source-mapped stack traces. When called via api.renderBlocks(), this is captured there to exclude the PluginApi wrapper.
 * @returns {Promise<Array<Object>>} Promise resolving to the validated layout array.
 * @throws {Error} If validation fails, or the outlet already has a code layout of the same kind (seed+seed or locked+locked).
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
export function _renderBlocks(outletName, layout, owner, options = {}) {
  const callSiteError = options.callSiteError ?? captureCallSite(_renderBlocks);
  const sourceId = options.sourceId ?? null;
  const overridable = options.overridable ?? CODE_LAYOUT_OVERRIDABLE_BY_DEFAULT;

  // Collision matrix against the two code slots. A second registration of the
  // SAME kind (seed+seed or locked+locked) is a conflict and throws, naming both
  // sources. A locked layout and an overridable seed may coexist: the lock wins
  // resolution and the seed is the fallback while both are present. Theme and
  // session-draft layers don't trip this — re-registering those (MessageBus, in-
  // session editing) is expected.
  const existing = outletLayouts.get(outletName);
  if (existing) {
    if (overridable && existing[CODE_OVERRIDABLE]) {
      raiseBlockError(
        `Block outlet "${outletName}" already has an overridable layout registered` +
          describeCodeSources(existing[CODE_OVERRIDABLE].sourceId, sourceId)
      );
    }
    if (!overridable && existing[CODE_LOCKED]) {
      raiseBlockError(
        `Block outlet "${outletName}" already has a locked layout registered` +
          describeCodeSources(existing[CODE_LOCKED].sourceId, sourceId)
      );
    }
  }

  return _setLayoutLayer(
    outletName,
    LAYOUT_LAYERS.CODE_DEFAULT,
    layout,
    owner,
    {
      callSiteError,
      overridable,
      sourceId,
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
 * Records that a `<BlockOutlet>` for `outletName` mounted, incrementing its
 * ref-count. Call from the outlet's constructor.
 *
 * @internal This is an internal API.
 * @param {string} outletName - The outlet identifier.
 */
export function _registerMountedOutlet(outletName) {
  mountedOutletCounts.set(
    outletName,
    (mountedOutletCounts.get(outletName) ?? 0) + 1
  );
}

/**
 * Records that a `<BlockOutlet>` for `outletName` was destroyed, decrementing its
 * ref-count and dropping the entry at zero. Call from the outlet's `willDestroy`.
 *
 * @internal This is an internal API.
 * @param {string} outletName - The outlet identifier.
 */
export function _unregisterMountedOutlet(outletName) {
  const next = (mountedOutletCounts.get(outletName) ?? 0) - 1;
  if (next > 0) {
    mountedOutletCounts.set(outletName, next);
  } else {
    mountedOutletCounts.delete(outletName);
  }
}

/**
 * Returns the set of outlet names with at least one `<BlockOutlet>` mounted on
 * the page. A point-in-time snapshot — see `mountedOutletCounts` for why it is
 * not tracked.
 *
 * @internal This is an internal API. Use the `blocks` service's `mountedOutletNames()` instead.
 * @returns {Set<string>} The mounted outlet names.
 */
export function _mountedOutletNames() {
  return new Set(mountedOutletCounts.keys());
}

/**
 * Returns the promise resolving to an outlet's validated layout entries, or
 * `undefined` when no layout is registered. Lets callers walk an outlet's
 * blocks before render (e.g. to resolve declared block data inside a route
 * transition) without instantiating the `BlockOutlet` component.
 *
 * @internal This is an internal API. Use the `blocks` service's `prepareData()` method instead.
 *
 * @param {string} outletName - The outlet identifier.
 * @returns {Promise<Array<LayoutEntry>>|undefined} The validated layout, or undefined.
 */
export function _getValidatedLayout(outletName) {
  return resolveLayoutRecord(outletName)?.validatedLayout;
}

/**
 * Returns the synchronously-resolved layout array for an outlet (the winning
 * layer's `layout`), or `null` when no layer is set. Resolves through
 * `resolveLayoutRecord`, so the `trackedMap` read is autotracked: a caller that
 * reads this inside a tracked context re-runs whenever any layer for the outlet
 * changes.
 *
 * Unlike `_getOutletLayouts`, this has no DEBUG gate, so it returns real data in
 * every build — which is what consumers outside test infrastructure need.
 *
 * Pass `ignoreSessionDraft: true` to resolve the underlying source's layout even
 * when an in-session draft is present — that is, the layout that owns the outlet
 * apart from any unsaved edit. Reading both (with and without the flag) yields the
 * baseline and the edited layout, which a consumer can compare.
 *
 * @internal This is an internal API. Use the `blocks` service's `resolvedLayout()` method instead.
 *
 * @param {string} outletName - The outlet identifier.
 * @param {Object} [options] - Resolution options.
 * @param {boolean} [options.ignoreSessionDraft=false] - When true, skip the session-draft layer and resolve the underlying source.
 * @returns {Array<LayoutEntry>|null} The resolved layout array, or null when no layer is set.
 */
export function _getResolvedLayout(
  outletName,
  { ignoreSessionDraft = false } = {}
) {
  return (
    resolveLayoutRecord(outletName, { ignoreSessionDraft })?.layout ?? null
  );
}

/**
 * Returns the provenance of an outlet's resolved layer — `{ source, sourceId,
 * overridable, themeStackIndex }` taken from the winning entry — or `null` when
 * no layer is set. Like `_getResolvedLayout`, it resolves through
 * `resolveLayoutRecord`, so the `trackedMap` read is autotracked (a caller that
 * reads this inside a tracked context re-runs whenever any layer for the outlet
 * changes) and there is no DEBUG gate.
 *
 * Pass `ignoreSessionDraft: true` to resolve the underlying layer's provenance
 * even when an in-session draft is present — that is, the source that owns the
 * outlet apart from any unsaved edit. The provenance fields are populated per
 * source: `overridable` is set only for code layers and `themeStackIndex` only
 * for theme layers (both `undefined` otherwise).
 *
 * @internal This is an internal API. Use the `blocks` service's `resolvedLayoutMeta()` method instead.
 *
 * @param {string} outletName - The outlet identifier.
 * @param {Object} [options] - Resolution options.
 * @param {boolean} [options.ignoreSessionDraft=false] - When true, skip the session-draft layer and resolve the underlying source.
 * @returns {{source: string, sourceId: (string|number|null), overridable: (boolean|undefined), themeStackIndex: (number|undefined)}|null} The resolved layer's provenance, or null when no layer is set.
 */
export function _getResolvedLayoutMeta(
  outletName,
  { ignoreSessionDraft = false } = {}
) {
  const entry = resolveLayoutRecord(outletName, { ignoreSessionDraft });
  if (!entry) {
    return null;
  }
  return {
    source: entry.source,
    sourceId: entry.sourceId ?? null,
    overridable: entry.overridable,
    themeStackIndex: entry.themeStackIndex,
  };
}

/**
 * Returns a Map of outlet name to its resolved `LayerEntry` for every outlet
 * that has a layer set. Allocates a fresh Map on each call — read it once per
 * computation and do not memoize, because reactivity comes from
 * `resolveLayoutRecord` reading the `trackedMap`: iterating inside a tracked
 * context subscribes to the relevant layer tags, so the consumer re-runs when a
 * layer changes.
 *
 * This is the production-safe counterpart to `_getOutletLayouts` (which is
 * DEBUG-gated test infrastructure); it returns the same `LayerEntry` shape, so
 * `record.layout` / `record.validatedLayout` reads keep working.
 *
 * @internal This is an internal API. Use the `blocks` service's `resolvedLayouts()` method instead.
 *
 * @returns {Map<string, LayerEntry>} The resolved outlet entries.
 */
export function _getResolvedLayouts() {
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

    // Record this outlet as mounted so consumers can enumerate the outlets on
    // the page, regardless of whether this one has a layout yet.
    _registerMountedOutlet(this.#name);
  }

  willDestroy() {
    // @ts-expect-error - Glimmer's willDestroy is variadic at the base.
    super.willDestroy(...arguments);

    // Drop this outlet's coordinated block data so a later mount re-resolves
    // rather than reusing payloads cached for a torn-down outlet.
    resetBlockData(this.#name);
    _unregisterMountedOutlet(this.#name);
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
      {{! Keep the rendered children mounted while a republished layout
          re-validates. Each republish produces a fresh validation promise;
          without retaining, the pending phase would unmount and rebuild the
          whole subtree (losing component state and re-running any data loads)
          on every republish. }}
      <DAsyncContent
        @asyncData={{this.children}}
        @retainWhileReloading={{true}}
      >
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
