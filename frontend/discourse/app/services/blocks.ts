import { getOwner, setOwner } from "@ember/owner";
import Service from "@ember/service";
import { TrackedAsyncData } from "ember-async-data";
import {
  _getResolvedLayout,
  _getResolvedLayoutMeta,
  _getResolvedLayouts,
  _getValidatedLayout,
  _hasLayout,
  _mountedOutletNames,
} from "discourse/blocks/block-outlet";
import type { BlockCondition } from "discourse/blocks/conditions";
import type { BlockMetadata, LayoutEntry } from "discourse/blocks/types";
import { synthesizePartEntries } from "discourse/lib/blocks/-internals/composite";
import { loadBlockData } from "discourse/lib/blocks/-internals/data-coordinator";
import { debugHooks } from "discourse/lib/blocks/-internals/debug-hooks";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import { titleCase } from "discourse/lib/blocks/-internals/display-metadata";
import {
  type ConditionEvaluationContext,
  evaluateConditions,
} from "discourse/lib/blocks/-internals/matching/condition-evaluator";
import {
  getAllBlockEntries,
  getBlockEntry,
  hasBlock,
  isBlockFactory,
  resolveBlock,
} from "discourse/lib/blocks/-internals/registry/block";
import { getAllConditionTypeEntries } from "discourse/lib/blocks/-internals/registry/condition";
import {
  getAllOutlets,
  getAllOutletsWithMetadata,
  getOutletMetadata,
} from "discourse/lib/blocks/-internals/registry/outlet";
import type {
  BlockClass,
  BlockRegistryEntry,
} from "discourse/lib/blocks/-internals/types";
import { applyArgDefaults } from "discourse/lib/blocks/-internals/utils";
import { validateConditions } from "discourse/lib/blocks/-internals/validation/conditions";
import isComponent from "discourse/lib/is-component";

/**
 * A registered block paired with its `@block` decorator metadata, as
 * returned by `listBlocksWithMetadata()`.
 */
export interface BlockInfo {
  /** The registered block name. */
  name: string;
  /** The block's registry entry: a resolved class, or a lazy factory. */
  component: BlockRegistryEntry;
  /** The block's `@block` decorator metadata, or `null` if unavailable. */
  metadata: BlockMetadata | null;
}

/**
 * Unified service for block registry and condition evaluation.
 *
 * ## Block Registry
 *
 * Provides introspection for registered block components:
 * - `getBlock(name)` - Get a block by name
 * - `hasBlock(name)` - Check if a block is registered
 * - `listBlocks()` - Get all registered blocks
 * - `listBlocksWithMetadata()` - Get all blocks with their metadata
 *
 * Core blocks are auto-discovered from `discourse/blocks/builtin`.
 * Theme/plugin blocks are registered via `api.registerBlock()` in pre-initializers.
 *
 * ## Condition Evaluation
 *
 * Evaluates block render conditions at runtime:
 * - `evaluate(conditionSpec)` - Evaluate condition(s)
 * - `validate(conditionSpec)` - Validate condition(s) at registration time
 *
 * Custom condition types are registered via `api.registerBlockConditionType()` in pre-initializers.
 * Built-in condition types are auto-discovered from `discourse/blocks/conditions`.
 *
 * Supports boolean combinators:
 * - Array of conditions: AND logic (all must pass)
 * - `{ any: [...] }`: OR logic (at least one must pass)
 * - `{ not: {...} }`: NOT logic (must fail)
 *
 * ## Debug Support
 *
 * - `showGhosts` - Check if visual overlay is enabled (for rendering ghost blocks)
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 */

/** Options accepted by the `prepareData` family of methods. */
interface PrepareDataOptions {
  /** Route params, available to future descriptor logic. */
  params?: Record<string, unknown>;

  /** Aborts in-flight resolution when the transition is cancelled. */
  signal?: AbortSignal;
}

export default class Blocks extends Service {
  /**
   * Map of condition type names to their instances.
   * Built lazily from the condition type registry when first accessed.
   */
  #conditionInstances = new Map<string, BlockCondition>();

  /**
   * Resolved lazy block thumbnails, keyed by the loader function. A lazily-loaded
   * thumbnail (`() => import(...)`) is fetched at most once and its resolution
   * reused everywhere, so a thumbnail that already resolved renders without a
   * loading state on later renders. Keyed by the loader reference, which is
   * stable (it lives in the frozen `@block` metadata).
   */
  #thumbnailData = new Map<object, TrackedAsyncData<unknown>>();

  /**
   * Tracks the registry size at last initialization to detect new registrations.
   *
   * We use size-based detection (rather than tracking individual type names) because:
   * 1. Condition types are only ever added, never removed
   * 2. Size comparison is O(1) vs O(n) for set difference
   * 3. Avoids allocating a Set<string> for tracking
   *
   * When `registry.size` is greater than `#lastKnownRegistrySize`, we know new
   * types were registered and need to create instances for them.
   */
  #lastKnownRegistrySize = 0;

  /**
   * Tracks the most recent prepare for each scope so a new prepare can abort the
   * one it supersedes. Keyed per scope (an outlet name): preparing one outlet
   * never cancels another's in-flight resolution.
   */
  #prepareControllers = new Map<string, AbortController>();

  /*
   * Block Outlet Methods
   */

  /**
   * Returns all registered block outlet names (both core and custom).
   *
   * Core outlets are defined in `lib/registry/block-outlets.ts`. Custom outlets
   * are registered by plugins and themes via `api.registerBlockOutlet()`.
   *
   * @returns Array of outlet names (e.g., ["hero-blocks", "homepage-blocks", ...]).
   *
   * @example
   * ```javascript
   * const outlets = this.blocks.listOutlets();
   * ```
   */
  listOutlets(): string[] {
    return getAllOutlets();
  }

  /**
   * Returns the set of outlet names with at least one `<BlockOutlet>` currently
   * mounted on the page — which, unlike `listOutlets()` (every registered
   * outlet) or `hasLayout()` (outlets with a layout), reflects what is actually
   * rendered here, even for outlets with no layout yet. Driven by the outlet's
   * own lifecycle, so it's populated as the page renders (before consumers that
   * enumerate outlets run). A point-in-time snapshot, not a tracked/reactive set.
   *
   * @returns The mounted outlet names.
   */
  mountedOutletNames() {
    return _mountedOutletNames();
  }

  /**
   * Returns every registered block outlet with its full display metadata.
   *
   * Unlike `listOutlets()` (which returns names only), this surfaces the
   * fields plugins/themes set via `api.registerBlockOutlet()` plus the
   * baked-in `CORE_OUTLET_METADATA` for the 5 core outlets, joined into a
   * single uniform shape with defaults filled in.
   *
   * Consumed by tooling that lists outlets so it can render display names,
   * descriptions, and category grouping. Each entry's `isCore` flag tells
   * the consumer whether the outlet is core or plugin-contributed;
   * `namespaceType` is parsed from the outlet name's prefix for ad-hoc
   * grouping.
   *
   * @returns
   *
   * @example
   * ```javascript
   * const outlets = this.blocks.listOutletsWithMetadata();
   * // [
   * //   { name: "hero-blocks", displayName: "Hero", description: "...",
   * //     category: null, isCore: true, namespaceType: "core" },
   * //   { name: "chat:thread-actions", displayName: "Thread actions", ... },
   * //   ...
   * // ]
   * ```
   */
  listOutletsWithMetadata() {
    return getAllOutletsWithMetadata();
  }

  /**
   * Returns the resolved display metadata for a single outlet by name (the
   * same shape `listOutletsWithMetadata()` yields per entry), or `null` when
   * the name isn't registered. Use this when a consumer already knows which
   * outlet it's rendering and only needs that one's display name, description,
   * and category rather than the full list.
   *
   * @param name - The full outlet name.
   * @returns
   *   The outlet's display metadata, or `null` for an unregistered name.
   */
  getOutletMetadata(name) {
    return getOutletMetadata(name);
  }

  /**
   * Returns every registered condition type with its display metadata and
   * argument schema.
   *
   * Consumed by tooling that lets authors add and configure conditions —
   * to populate the available condition types and render per-type input
   * fields. Each entry's fields come from the `@blockCondition(...)`
   * decorator:
   *
   * - `type` — the condition's stable identifier (`"user"`, `"viewport"`, …).
   * - `displayName` — human-readable label; defaults to a Title Case of
   *   `type` when the condition didn't set one.
   * - `description` — one-line summary of what the condition matches.
   * - `argsSchema` — the typed arg map declared on the decorator.
   * - `sourceType` — `"none" | "outletArgs" | "object"`.
   * - `constraints` — cross-arg validation constraints, if any.
   * - `namespaceType` — `"core" | "plugin" | "theme"`.
   *
   * @returns One descriptor per registered condition type, with the fields
   *   listed above.
   */
  listConditionTypes() {
    return getAllConditionTypeEntries().map(([type, ConditionClass]) => ({
      type,
      displayName: ConditionClass.displayName ?? titleCase(type),
      description: ConditionClass.description ?? null,
      argsSchema: ConditionClass.argsSchema ?? {},
      sourceType: ConditionClass.sourceType,
      constraints: ConditionClass.constraints ?? null,
      namespaceType: ConditionClass.namespaceType,
    }));
  }

  /**
   * Checks if a layout has been registered for a given block outlet.
   *
   * A layout is registered when a plugin or theme calls `api.renderBlocks()`
   * for an outlet. This method allows checking layout presence outside of
   * `BlockOutlet` templates.
   *
   * @param outletName - The outlet identifier to check.
   * @returns True if a layout is registered for this outlet.
   *
   * @example
   * ```javascript
   * if (this.blocks.hasLayout("homepage-blocks")) {
   *   // Outlet has blocks registered
   * }
   * ```
   */
  hasLayout(outletName: string): boolean {
    return _hasLayout(outletName);
  }

  /**
   * Returns the resolved layout array for a single outlet (the winning layer's
   * layout), or `null` when no layer is set. Reactive: reading this inside a
   * tracked context re-runs when the outlet's resolved layer changes.
   *
   * Pass `ignoreSessionDraft: true` to resolve the underlying source's layout even
   * when an in-session draft is present — the layout that owns the outlet apart
   * from any unsaved edit. Reading both yields the baseline and the edited layout.
   *
   * @param outletName - The outlet identifier.
   * @param options - Resolution options; `ignoreSessionDraft` (default `false`)
   *   skips the session-draft layer and resolves the underlying source.
   * @returns The resolved layout array, or null.
   */
  resolvedLayout(outletName, { ignoreSessionDraft = false } = {}) {
    return _getResolvedLayout(outletName, { ignoreSessionDraft });
  }

  /**
   * Returns the provenance of an outlet's resolved layer — its source,
   * sourceId, overridable flag, and themeStackIndex — or `null` when no layer
   * is set. Reactive: reading this inside a tracked context re-runs when the
   * outlet's resolved layer changes.
   *
   * Pass `{ ignoreSessionDraft: true }` to resolve the underlying source that
   * owns the outlet apart from any in-session edit (the draft layer otherwise
   * masks it).
   *
   * @param outletName - The outlet identifier.
   * @param options - Resolution options; `ignoreSessionDraft` (default `false`)
   *   skips the session-draft layer.
   * @returns The resolved layer's provenance, or null.
   */
  resolvedLayoutMeta(outletName, options) {
    return _getResolvedLayoutMeta(outletName, options);
  }

  /**
   * Returns a Map of outlet name to its resolved layer entry for every outlet
   * with a layer set. Reactive when read inside a tracked context.
   *
   * @returns The resolved outlet entries.
   */
  resolvedLayouts() {
    return _getResolvedLayouts();
  }

  /*
   * Block Registry Methods
   */

  /**
   * Gets a registered block by name.
   *
   * @param name - The block name (e.g., "hero-banner")
   * @returns The block entry, or undefined if not found
   *
   * @example
   * ```javascript
   * const HeroBanner = this.blocks.getBlock("hero-banner");
   * ```
   */
  getBlock(name: string): BlockRegistryEntry | undefined {
    return getBlockEntry(name);
  }

  /**
   * Checks if a block is registered.
   *
   * @param name - The block name
   *
   * @example
   * ```javascript
   * if (this.blocks.hasBlock("hero-banner")) {
   *   // Block is available
   * }
   * ```
   */
  hasBlock(name: string): boolean {
    return hasBlock(name);
  }

  /**
   * Returns all registered block entries.
   *
   * @example
   * ```javascript
   * const allBlocks = this.blocks.listBlocks();
   * ```
   */
  listBlocks(): BlockRegistryEntry[] {
    return getAllBlockEntries().map(([, entry]) => entry);
  }

  /**
   * Returns all registered blocks with their metadata.
   * Useful for admin UIs and documentation generation.
   *
   * @example
   * ```javascript
   * const blocksInfo = this.blocks.listBlocksWithMetadata();
   * blocksInfo.forEach(({ name, metadata }) => {
   *   console.log(name, metadata.description, metadata.args);
   * });
   * ```
   */
  listBlocksWithMetadata(): BlockInfo[] {
    return getAllBlockEntries().map(([name, component]) => ({
      name,
      component,
      metadata: getBlockMetadata(component),
    }));
  }

  /**
   * Asynchronously gets a registered block by name, resolving factories if needed.
   *
   * Unlike `getBlock()` which returns the raw registry entry (which may be a factory),
   * this method ensures the returned value is always a resolved BlockClass.
   *
   * @param name - The block name (e.g., "hero-banner").
   * @returns The resolved block class, or undefined if not found.
   *
   * @example
   * ```javascript
   * const HeroBanner = await this.blocks.getBlockAsync("hero-banner");
   * if (HeroBanner) {
   *   // Block is ready to use
   * }
   * ```
   */
  async getBlockAsync(name: string): Promise<BlockClass | undefined> {
    if (!hasBlock(name)) {
      return undefined;
    }
    try {
      return await resolveBlock(name);
    } catch {
      return undefined;
    }
  }

  /**
   * Checks if a block is registered and fully resolved (not a pending factory).
   *
   * Use this to check if a block is immediately available without needing async resolution.
   * Returns false for unregistered blocks or blocks that are registered as factory functions
   * but haven't been resolved yet.
   *
   * @param name - The block name.
   * @returns True if registered and immediately available.
   *
   * @example
   * ```javascript
   * if (this.blocks.isBlockReady("hero-banner")) {
   *   // Block is available synchronously
   *   const HeroBanner = this.blocks.getBlock("hero-banner");
   * } else {
   *   // Block needs async resolution
   *   const HeroBanner = await this.blocks.getBlockAsync("hero-banner");
   * }
   * ```
   */
  isBlockReady(name: string): boolean {
    if (!hasBlock(name)) {
      return false;
    }
    const entry = getBlockEntry(name);
    return !isBlockFactory(entry);
  }

  /**
   * Resolves a lazy thumbnail loader to its component, caching the resolution so
   * each loader is fetched at most once. The loader may resolve to the component
   * directly or to a module whose `default` export is the component, so both
   * shapes are unwrapped.
   *
   * Returns a `TrackedAsyncData` (not a bare promise) so a consumer can render
   * loading, resolved, and error states reactively, and so an already-resolved
   * loader reports `content` immediately on later renders — no repeated loading
   * state. `TrackedAsyncData` handles rejection internally.
   *
   * @param loader - A thumbnail loader thunk (e.g. `() => import(...)`).
   * @returns The resolution state.
   *
   * @example
   * ```javascript
   * const data = this.blocks.thumbnailData(metadata.thumbnail);
   * if (data.isResolved) {
   *   const ThumbnailComponent = data.value;
   * }
   * ```
   */
  thumbnailData(loader) {
    let data = this.#thumbnailData.get(loader);
    if (!data) {
      const promise = Promise.resolve(loader()).then(
        (resolved) => resolved?.default ?? resolved
      );
      data = new TrackedAsyncData(promise);
      this.#thumbnailData.set(loader, data);
    }
    return data;
  }

  /**
   * Warms the thumbnail cache for every registered block that declares a lazy
   * loader thumbnail, so a later render shows the thumbnails without a loading
   * state. Fire-and-forget and safe to call repeatedly — resolution is deduped
   * per loader.
   *
   * @example
   * ```javascript
   * // On entering an editing context, ahead of rendering the thumbnails:
   * this.blocks.prefetchThumbnails();
   * ```
   */
  prefetchThumbnails() {
    for (const { metadata } of this.listBlocksWithMetadata()) {
      const thumbnail = metadata?.thumbnail;
      // A component is itself a function, so a lazy loader is a function that is
      // not already a renderable component.
      if (typeof thumbnail === "function" && !isComponent(thumbnail)) {
        this.thumbnailData(thumbnail);
      }
    }
  }

  /*
   * Block Data Methods
   */

  /**
   * Resolves the declared data for every block in an outlet's layout and waits
   * for it to settle, so the blocks render with their data already in hand.
   *
   * Intended to be awaited inside a route transition (from `model()` /
   * `afterModel()`): the transition waits, the route's loading substate covers
   * it, and navigating away cancels the work. Resolution prefers server-inlined
   * preload payloads; otherwise it runs each block's resolver. Per-block
   * failures do not reject — they surface at render through the block's own
   * loading boundary — so one failing block can't break the transition.
   *
   * Blocks hidden by render-time-only conditions are still resolved here (a
   * harmless superset); their data simply goes unused.
   *
   * @param scope - The outlet name whose blocks to resolve.
   * @param options - Resolution options.
   * @returns A promise that resolves once the blocks' data is prepared.
   */
  async prepareData(
    scope: string,
    options: PrepareDataOptions = {}
  ): Promise<void> {
    return this.#prepareData(scope, options);
  }

  /**
   * Route-facing entry point for `prepareData` that owns the abort lifecycle, so
   * a route only names its outlet and awaits.
   *
   * Each call supersedes the previous prepare of the same scope: it aborts the
   * prior in-flight resolution (e.g. when a query-param refresh re-enters the
   * route) before starting a fresh one, so a superseded load can't keep running.
   *
   * Await it from a route's `model()` / `afterModel()` so the transition waits
   * for the data and the route's loading substate covers it.
   *
   * @param scope - The outlet name whose blocks to resolve.
   * @param options - Resolution options.
   * @returns A promise that resolves once the blocks' data is prepared.
   */
  async prepareDataForRoute(
    scope: string,
    options: PrepareDataOptions = {}
  ): Promise<void> {
    this.#prepareControllers.get(scope)?.abort();

    const controller = new AbortController();
    this.#prepareControllers.set(scope, controller);

    try {
      await this.#prepareData(scope, { ...options, signal: controller.signal });
    } finally {
      // Leave a newer prepare's controller in place: only clear our own.
      if (this.#prepareControllers.get(scope) === controller) {
        this.#prepareControllers.delete(scope);
      }
    }
  }

  async #prepareData(
    scope: string,
    options: PrepareDataOptions = {}
  ): Promise<void> {
    const layoutPromise = _getValidatedLayout(scope);
    if (!layoutPromise) {
      return;
    }

    const { signal } = options;
    const owner = getOwner(this);
    const entries = await layoutPromise;

    const promises = [];
    await this.#collectBlockDataPromises(
      scope,
      entries,
      owner,
      signal,
      promises
    );

    await Promise.allSettled(promises);
  }

  /**
   * Walks layout entries (depth-first into containers), starting resolution for
   * every block that declares a data dependency and collecting the promises.
   *
   * @param scope - The outlet name.
   * @param entries - Validated layout entries.
   * @param owner - The application owner.
   * @param signal - Cancellation signal.
   * @param out - Accumulator for the resolution promises.
   * @returns
   */
  async #collectBlockDataPromises(scope, entries, owner, signal, out) {
    for (const entry of entries ?? []) {
      const blockClass = await this.#resolveBlockClass(entry.block);
      const metadata = blockClass ? getBlockMetadata(blockClass) : null;
      const dataMeta = metadata?.data;

      if (dataMeta?.request) {
        // Apply schema defaults so the descriptor (and therefore the cache key)
        // matches the one the layout wrapper derives at render time.
        const args = applyArgDefaults(blockClass, entry.args ?? {});
        const descriptor = dataMeta.request(args);
        const cacheEntry = loadBlockData({
          scope,
          blockName: metadata.blockName,
          descriptor,
          dataMeta,
          owner,
          signal,
        });
        if (cacheEntry) {
          out.push(cacheEntry.promise);
        }
      }

      // Walk into children the same way the render pipeline does: explicit
      // children when present, otherwise the synthesized parts of a
      // composition. This keeps a data-owning part (at any nesting depth)
      // prefetched even when the composite supplies no children of its own.
      let children;
      if (entry.children?.length) {
        children = entry.children;
      } else if (metadata?.parts && entry.children == null) {
        children = synthesizePartEntries(entry, metadata);
      }

      if (children?.length) {
        await this.#collectBlockDataPromises(
          scope,
          children,
          owner,
          signal,
          out
        );
      }
    }
  }

  /**
   * Resolves a layout entry's block reference (a component class or a registered
   * name) to its component class, or null when it can't be resolved.
   *
   * @param blockRef - The entry's block reference.
   * @returns The component class, or null.
   */
  async #resolveBlockClass(blockRef) {
    if (typeof blockRef === "function") {
      return blockRef;
    }
    if (typeof blockRef === "string") {
      try {
        return await resolveBlock(blockRef);
      } catch {
        return null;
      }
    }
    return null;
  }

  /*
   * Condition Evaluation Methods
   */

  /**
   * Lazily initializes condition instances from the registry.
   *
   * This deferred initialization pattern handles the timing issue where:
   * 1. Service is instantiated early (e.g., during plugin API usage)
   * 2. Core conditions are registered later by the pre-initializer
   * 3. Service needs to pick up the newly registered conditions
   *
   * Called at the start of validate(), evaluate(), and other condition methods.
   */
  #lazilyInitializeConditionInstances(): void {
    const entries = getAllConditionTypeEntries();

    // Only rebuild if registry has grown since last check
    if (entries.length === this.#lastKnownRegistrySize) {
      return;
    }

    // Create instances for any new condition types
    for (const [type, ConditionClass] of entries) {
      if (!this.#conditionInstances.has(type)) {
        this.#createConditionInstance(type, ConditionClass);
      }
    }

    this.#lastKnownRegistrySize = entries.length;
  }

  /**
   * Creates an instance of a condition class and stores it in the instances map.
   * Sets the owner on the instance to enable service injection.
   *
   * @param type - The condition type name.
   * @param ConditionClass - The condition class.
   */
  #createConditionInstance(
    type: string,
    ConditionClass: typeof BlockCondition
  ): void {
    const instance = new ConditionClass();
    // This service instance is always Ember-owned (services are only ever
    // instantiated through the DI container), so `getOwner(this)` is never
    // undefined here.
    setOwner(instance, getOwner(this)!);
    this.#conditionInstances.set(type, instance);
  }

  /**
   * Validates condition specs at block registration time.
   * Recursively validates nested conditions in `any` and `not` combinators.
   *
   * Throws BlockError objects so callers can decide how to format
   * the final error with appropriate context. The error object includes a
   * `path` property indicating where in the conditions the error occurred
   * (relative to the conditions root, e.g., "params.categoryId").
   *
   * @param conditionSpec - Condition spec(s) to validate.
   * @throws A `BlockError` if validation fails.
   */
  validate(conditionSpec: LayoutEntry["conditions"]): void {
    this.#lazilyInitializeConditionInstances();
    validateConditions(conditionSpec, this.#conditionInstances);
  }

  /**
   * Evaluates condition specs at render time.
   * Recursively evaluates nested conditions with AND/OR/NOT logic.
   *
   * @param conditionSpec - Condition spec(s) to evaluate.
   * @param context - Evaluation context.
   * @returns True if conditions pass, false otherwise.
   */
  evaluate(
    conditionSpec: LayoutEntry["conditions"],
    context: ConditionEvaluationContext = {}
  ): boolean {
    this.#lazilyInitializeConditionInstances();
    return evaluateConditions(conditionSpec, this.#conditionInstances, context);
  }

  /**
   * Checks if a condition type is registered.
   *
   * @param type - The condition type name
   */
  hasConditionType(type: string): boolean {
    this.#lazilyInitializeConditionInstances();
    return this.#conditionInstances.has(type);
  }

  /**
   * Returns all registered condition type names.
   * Useful for debugging and error messages.
   */
  getRegisteredConditionTypes(): string[] {
    this.#lazilyInitializeConditionInstances();
    return [...this.#conditionInstances.keys()];
  }

  /*
   * Debug Methods
   */

  /**
   * Returns whether the debug visual overlay is enabled.
   *
   * Container blocks can use this to conditionally render ghost blocks
   * for children they choose not to display.
   *
   * @returns True if the visual overlay (ghost blocks) is enabled.
   *
   * @example
   * ```javascript
   * if (this.blocks.showGhosts) {
   *   // Render ghost blocks for hidden children
   * }
   * ```
   */
  get showGhosts(): boolean {
    return debugHooks.isGhostBlocksEnabled;
  }
}
