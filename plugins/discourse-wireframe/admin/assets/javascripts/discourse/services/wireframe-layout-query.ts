import Service, { service } from "@ember/service";
import {
  _getResolvedLayout,
  _getResolvedLayouts,
  LAYOUT_SOURCE,
  type ResolvedLayoutMeta,
} from "discourse/blocks/block-outlet";
import type { BlockMetadata, LayoutEntry } from "discourse/blocks/types";
import { PART_KEY_SEGMENT } from "discourse/lib/blocks/-internals/composite";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import type { BlockRegistryEntry } from "discourse/lib/blocks/-internals/types";
import type Blocks from "discourse/services/blocks";
import {
  entryKey,
  findAncestryPath as findAncestryPathUntyped,
  findEntry as findEntryUntyped,
  findEntryByStableKey as findEntryByStableKeyUntyped,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";

/*
 * `mutate-layout` is authored in `@ts-check` JavaScript, whose JSDoc `{Object}`
 * return types surface to a TypeScript consumer as the near-useless `Object`.
 * Re-type its three entry lookups against their real `LayoutEntry` contract at
 * the import boundary so the call sites below read precise entries.
 * TODO(devxp-typescript-pending): drop these aliases once `mutate-layout` is
 * authored in TypeScript and exports precise signatures.
 */
const findEntry = findEntryUntyped as unknown as (
  layout: LayoutEntry[],
  key: string
) => LayoutEntry | null;

const findEntryByStableKey = findEntryByStableKeyUntyped as unknown as (
  layout: LayoutEntry[],
  stableKey: string
) => LayoutEntry | null;

const findAncestryPath = findAncestryPathUntyped as unknown as (
  layout: LayoutEntry[],
  key: string
) => LayoutEntry[] | null;

/**
 * Per-outlet resolved-layout record: the synchronously-available layout plus
 * the promise of its validated form. This is the author-facing `LayoutEntry`
 * view of the core layer record, whose internal entry shape this layer never
 * inspects.
 */
interface ResolvedLayoutRecord {
  layout: LayoutEntry[];
  validatedLayout: Promise<LayoutEntry[]>;
}

/**
 * The persistence state of an outlet, derived from the source that owns it
 * apart from any in-session edit (see `outletState`). `EDITING` is orthogonal —
 * an outlet in any of these states may also have unsaved edits.
 *
 * - `LOCKED` — a non-overridable programmatic layout owns it; read-only.
 * - `DEFAULT` — an overridable in-code seed (or nothing published yet).
 * - `PUBLISHED` — a theme field owns it.
 */
export const OUTLET_STATE = Object.freeze({
  LOCKED: "locked",
  DEFAULT: "default",
  PUBLISHED: "published",
});

/**
 * The outlet/layout query layer — the read path the editor funnels every
 * "where does this block live, what is it, can this outlet be edited" question
 * through. A pure-read peer service: it reads the same draft-aware resolved
 * layout the live page sees (via the core block-outlet readers, wrapped in the
 * `_resolved*` seam methods below) plus block metadata from the `blocks`
 * service, and never reaches back into the editor. It is mostly read-only; the
 * one write surface is the outlet-root identity bookkeeping
 * (`recordOutletRoot` / `clearOutletRoots`) the orchestrator drives.
 *
 * Kept un-cached on purpose: the resolved-layout reads feed off tracked sources
 * at call time, so a template binding re-runs when those layers change; caching
 * would freeze on an untracked early read.
 */
export default class WireframeLayoutQueryService extends Service {
  @service declare blocks: Blocks;

  /**
   * Maps each drafted outlet to the composite key of its implicit root
   * `layout` block. Every drafted outlet is normalised to a single root
   * layout (see `wrapAsOutletRoot`); selecting that key is how the editor
   * "selects the outlet", and `isOutletRoot` consults this map to suppress
   * block-level affordances (move / duplicate / delete) on the root.
   *
   * Populated when the draft is materialised (the orchestrator calls
   * `recordOutletRoot`) and cleared on `exit`. Not persisted — the root key is
   * re-derived from the published draft each session.
   */
  #outletRootKeys = new Map<string, string>();

  /**
   * The names of every block outlet that's editable on the current page — either
   * one that already has a registered layout or one whose `<BlockOutlet>` is
   * mounted in the DOM with no layout yet. Including the empty-mounted case makes
   * "start a layout from scratch" possible — the entry pill surfaces even when no
   * code path has called `api.renderBlocks(...)` for that outlet. Mounted outlets
   * that aren't registered are silently ignored (they can't have a layout).
   */
  get editableOutlets(): string[] {
    const registered = this.blocks.listOutlets();
    const mounted = this.blocks.mountedOutletNames();
    return registered.filter(
      (name) => this.blocks.hasLayout(name) || mounted.has(name)
    );
  }

  /* Resolved-layout reads */

  /**
   * Returns the resolved layout array for an outlet, or null when no layout
   * is registered. Used by the live-layout service to grab the snapshot of
   * an edited outlet that needs to be POSTed.
   *
   * Pass `ignoreSessionDraft: true` to resolve the underlying source's layout —
   * what is live now, apart from any unsaved edit. Reading both (with and without
   * the flag) yields the baseline and the edited layout for a change comparison.
   *
   * @param options.ignoreSessionDraft - When true, skip the session-draft layer and resolve the underlying source.
   */
  readResolvedLayout(
    outletName: string,
    { ignoreSessionDraft = false }: { ignoreSessionDraft?: boolean } = {}
  ): LayoutEntry[] | null {
    return this._resolvedLayout(outletName, { ignoreSessionDraft });
  }

  /* Entry / outlet lookups */

  /**
   * Synchronous variant of `findEntryAndOutlet` — uses `record.layout`
   * (already-resolved) instead of awaiting `record.validatedLayout`. Drag
   * handlers fire after validation has long since completed, so the sync
   * lookup is safe and avoids forcing every call site to be async.
   */
  findEntryAndOutletSync(
    key: string
  ): { entry: LayoutEntry; outletName: string } | null {
    const layoutMap = this._resolvedLayouts();
    for (const [outletName, record] of layoutMap) {
      if (!record.layout) {
        continue;
      }
      const found = findEntry(record.layout, key);
      if (found) {
        return { entry: found, outletName };
      }
    }
    return null;
  }

  /**
   * @returns The live entry, or `null` when no outlet resolves the key.
   */
  findEntryByKey(key: string): LayoutEntry | null {
    return this.findEntryAndOutletSync(key)?.entry ?? null;
  }

  /**
   * Walks every registered outlet's resolved layout looking for the entry
   * whose composite key matches. Returns the live entry plus its containing
   * outlet name so the caller can both mutate `entry.args` in place AND
   * tell persistence which outlet just got dirty.
   */
  async findEntryAndOutlet(
    key: string
  ): Promise<{ entry: LayoutEntry; outletName: string } | null> {
    const layoutMap = this._resolvedLayouts();
    for (const [outletName, record] of layoutMap) {
      let layout;
      try {
        layout = await record.validatedLayout;
      } catch {
        continue;
      }
      const found = findEntry(layout, key);
      if (found) {
        return { entry: found, outletName };
      }
    }
    return null;
  }

  /**
   * Locates the immediate parent entry of `blockKey` by walking the
   * resolved layout. Returns `null` when the key isn't found or when
   * the entry sits at the outlet root (no block-level parent).
   *
   * Used by chrome decoration to determine context — e.g. showing a
   * resize handle only when the block sits inside a grid layout.
   */
  findEntryParent(blockKey: string): LayoutEntry | null {
    const located = this.findEntryAndOutletSync(blockKey);
    if (!located) {
      return null;
    }
    const layout = this.readResolvedLayout(located.outletName);
    if (!layout) {
      return null;
    }
    const path = findAncestryPath(layout, blockKey);
    if (!path || path.length < 2) {
      return null;
    }
    return path[path.length - 2];
  }

  /**
   * Returns `true` when `ancestorKey` appears in `descendantKey`'s
   * ancestry path. Used by chrome decoration to keep the grid overlay
   * mounted while the user is editing one of the layout's children
   * (the layout itself stops being `selectedBlockKey` once the user
   * clicks into a cell, but the overlay should stay visible until they
   * navigate fully away).
   */
  isAncestorOf(ancestorKey: string, descendantKey: string): boolean {
    if (!ancestorKey || !descendantKey || ancestorKey === descendantKey) {
      return false;
    }
    const located = this.findEntryAndOutletSync(descendantKey);
    if (!located) {
      return false;
    }
    const layout = this.readResolvedLayout(located.outletName);
    if (!layout) {
      return false;
    }
    const path = findAncestryPath(layout, descendantKey);
    if (!path) {
      return false;
    }
    return path.some((entry) => entryKey(entry) === ancestorKey);
  }

  /**
   * Resolves a synthesized part's selection key to the composite that owns it.
   * A part has no persisted entry — its key encodes the owning composite's
   * stable key plus a dot-path of part ids (e.g. `heading:42::part::title` or
   * `button-link:42::part::actions::part::primary`). Returns the composite
   * entry, its key, the outlet, and the override path, or null when the key
   * isn't a part key (or the composite can't be found).
   */
  resolvePartContext(key: string): {
    compositeEntry: LayoutEntry;
    compositeKey: string;
    outletName: string;
    idPath: string[];
    partPath: string;
  } | null {
    if (!key || !key.includes(PART_KEY_SEGMENT)) {
      return null;
    }
    const segments = key.split(PART_KEY_SEGMENT);
    // The head is `${leafBlockName}:${compositeStableKey}`; the block name may
    // itself contain ":" (plugin/theme blocks), so take the last ":" segment.
    const head = segments[0];
    const compositeStableKey = head.slice(head.lastIndexOf(":") + 1);
    const idPath = segments.slice(1);

    const layoutMap = this._resolvedLayouts();
    for (const [outletName, record] of layoutMap) {
      if (!record.layout) {
        continue;
      }
      const compositeEntry = findEntryByStableKey(
        record.layout,
        compositeStableKey
      );
      if (compositeEntry) {
        return {
          compositeEntry,
          compositeKey: entryKey(compositeEntry),
          outletName,
          idPath,
          partPath: idPath.join("."),
        };
      }
    }
    return null;
  }

  /* Block metadata / names */

  /**
   * Resolves an entry's block name. `entry.block` is either a class
   * reference (decorated blocks) or a string-ref (api.renderBlocks
   * factories) — this helper smooths over the two shapes.
   */
  blockNameOf(entry: LayoutEntry | null): string | null {
    if (!entry?.block) {
      return null;
    }
    if (typeof entry.block === "string") {
      return entry.block;
    }
    return this.metadataFor(entry)?.blockName ?? null;
  }

  metadataFor(entry: LayoutEntry | null): BlockMetadata | null {
    if (!entry?.block) {
      return null;
    }
    if (typeof entry.block === "string") {
      // String-ref blocks (`api.renderBlocks(name, ...)` paths) expose their
      // metadata via the registered class — looked up through the blocks
      // service. Skipping for now keeps the perms check simple.
      return null;
    }
    return getBlockMetadata(entry.block) ?? null;
  }

  /**
   * Resolves the metadata for a registered block by name. Returns null
   * for unknown names or when the registry entry is a factory the block
   * service hasn't materialised yet — same permissive contract as
   * `metadataFor` for moves.
   */
  metadataForName(blockName: string): BlockMetadata | null {
    const klass = this._block(blockName);
    if (!klass || typeof klass !== "function") {
      return null;
    }
    return getBlockMetadata(klass);
  }

  /**
   * Returns the block's metadata bag for any block-reference form
   * (string registry name or class). Convenience over picking
   * between `metadataForName` (string) and `getBlockMetadata`
   * (class) at the call site.
   */
  lookupBlockMetadata(blockRef: LayoutEntry["block"]): BlockMetadata | null {
    if (typeof blockRef === "function") {
      return getBlockMetadata(blockRef) ?? null;
    }
    return this.metadataForName(blockRef);
  }

  /**
   * Pulls the human-readable display name for a block from its
   * metadata. The drop-preview overlay uses this so labels match
   * the palette / outline vocabulary the author already sees
   * elsewhere. Falls back to the block name itself when no
   * display name is set.
   */
  lookupBlockDisplayName(blockRef: LayoutEntry["block"]): string | null {
    const name = this.#blockNameFor(blockRef);
    if (!name) {
      return null;
    }
    return this.metadataForName(name)?.displayName ?? name;
  }

  /* Outlet state */

  /**
   * The persistence state of an outlet — one of `OUTLET_STATE`. Derived from
   * the source that owns the outlet apart from any in-session edit (the draft
   * layer is ignored on purpose, so this reflects what is actually published,
   * not the unsaved edit on top). Whether the outlet has unsaved edits is
   * reported separately by `isOutletEditing`.
   *
   * Reads the resolved provenance directly (one keyed, tracked map read), so a
   * template binding re-runs when the outlet's layers change. Kept a plain
   * method — never `@cached` — so it can't freeze on an untracked early read.
   *
   * @returns One of `OUTLET_STATE`.
   */
  outletState(outletName: string): string {
    const meta = this._resolvedLayoutMeta(outletName, {
      ignoreSessionDraft: true,
    });
    if (meta?.source === LAYOUT_SOURCE.THEME) {
      return OUTLET_STATE.PUBLISHED;
    }
    if (meta?.source === LAYOUT_SOURCE.CODE && meta.overridable === false) {
      return OUTLET_STATE.LOCKED;
    }
    // An overridable in-code seed, or no underlying layer at all, is the default.
    return OUTLET_STATE.DEFAULT;
  }

  /**
   * Whether an outlet may be edited. A LOCKED outlet is read-only; everything
   * else is editable.
   */
  isOutletEditable(outletName: string): boolean {
    return this.outletState(outletName) !== OUTLET_STATE.LOCKED;
  }

  /* Grid predicates */

  /**
   * Whether the entry is a `wf:layout` in per-cell `grid` mode. Accepts
   * the legacy `"free-grid"` mode value as an alias so existing saved
   * layouts (pre-rename) keep working.
   */
  isGridContainer(entry: LayoutEntry | null): boolean {
    if (this.blockNameOf(entry) !== "layout") {
      return false;
    }
    const mode = entry?.args?.mode;
    return mode === "grid" || mode === "free-grid";
  }

  /**
   * Whether the entry is a grid-cell occupant — a direct child of a
   * `wf:layout` in grid mode, carrying its own `containerArgs.grid`
   * placement. Used by the editor to decide whether a given entry can
   * be placement-mutated (set its column/row, swap with a sibling, etc.).
   */
  isGridCellEntry(entry: LayoutEntry | null): boolean {
    return entry?.containerArgs?.grid != null;
  }

  /**
   * Whether `entry` is a grid-cell occupant whose direct parent is the
   * layout identified by `gridKey`. Used by the grid manipulator to tell a
   * same-grid source (re-placed in situ) from one arriving from elsewhere.
   */
  isCellInGrid(entry: LayoutEntry, gridKey: string): boolean {
    if (!this.isGridCellEntry(entry)) {
      return false;
    }
    const parent = this.findEntryParent(entryKey(entry));
    return parent && entryKey(parent) === gridKey;
  }

  /* Composite predicates */

  /**
   * Whether the block at `blockKey` is a *composed* composite — a block that
   * declares a `parts` composition and renders it (no `children` of its own).
   * Drives the "Detach" affordance: only composed composites can be detached.
   * A synthesized part (no persisted entry) and a detached composite (explicit
   * `children`) both return false.
   */
  isComposedComposite(blockKey: string): boolean {
    const entry = this.findEntryAndOutletSync(blockKey)?.entry;
    if (!entry || entry.children != null) {
      return false;
    }
    const name = this.blockNameOf(entry);
    const metadata = name ? this.metadataForName(name) : null;
    return !!metadata?.parts;
  }

  /* Outlet-root identity */

  /**
   * Records the implicit root layout key for an outlet. Reads the just-
   * published draft's first entry — every drafted outlet is normalised to a
   * single root `layout` block, so `[0]` is always that root.
   */
  recordOutletRoot(outletName: string): void {
    const root = this.readResolvedLayout(outletName)?.[0];
    if (root) {
      this.#outletRootKeys.set(outletName, entryKey(root));
    }
  }

  /**
   * The composite key of an outlet's implicit root `layout` block, or `null`
   * when the outlet hasn't been drafted yet.
   */
  outletRootKey(outletName: string): string | null {
    return this.#outletRootKeys.get(outletName) ?? null;
  }

  /**
   * Whether `key` identifies an outlet's implicit root `layout` block. The
   * chrome and inspector consult this to present the root AS the outlet —
   * suppressing block-level affordances (move / duplicate / delete) that
   * don't apply to a page region.
   */
  isOutletRoot(key: string | null): boolean {
    if (key == null) {
      return false;
    }
    for (const rootKey of this.#outletRootKeys.values()) {
      if (rootKey === key) {
        return true;
      }
    }
    return false;
  }

  /**
   * Forgets every recorded outlet-root key. Called on session exit so a fresh
   * session re-derives the root keys from the published drafts.
   */
  clearOutletRoots(): void {
    this.#outletRootKeys.clear();
  }

  /**
   * Best-effort lookup of the outlet name that owns `entry`. Walks the
   * currently-resolved layout map; returns null when the entry is no longer
   * present (e.g. it's been moved out of every published layer). Used by
   * `resetAll` to decide which arg-snapshots to drop after a structural
   * rollback.
   */
  outletForEntry(entry: LayoutEntry): string | null {
    const layoutMap = this._resolvedLayouts();
    for (const [outletName, record] of layoutMap) {
      if (record.layout && this.#layoutContainsEntry(record.layout, entry)) {
        return outletName;
      }
    }
    return null;
  }

  /* Private helpers */

  /**
   * Resolves a block reference (either a registry name string or
   * the decorated class itself, as it appears in layout entries)
   * to its canonical block name string. Returns `null` for
   * unresolvable references.
   */
  #blockNameFor(blockRef: LayoutEntry["block"]): string | null {
    if (typeof blockRef === "string") {
      return blockRef;
    }
    return getBlockMetadata(blockRef)?.blockName ?? null;
  }

  #layoutContainsEntry(layout: LayoutEntry[], target: LayoutEntry): boolean {
    for (const entry of layout) {
      if (entry === target) {
        return true;
      }
      if (
        entry.children?.length &&
        this.#layoutContainsEntry(entry.children, target)
      ) {
        return true;
      }
    }
    return false;
  }

  /* Core-reader seams (overridable for tests) */

  /**
   * The draft-aware resolved layout for an outlet. A thin seam over the core
   * reader so tests can stub it with fixture layouts.
   */
  _resolvedLayout(
    outletName: string,
    options?: { ignoreSessionDraft?: boolean }
  ): LayoutEntry[] | null {
    // The core reader hands back the internal entry shape; this layer only ever
    // reads the author-facing `LayoutEntry` view of it.
    return _getResolvedLayout(outletName, options) as unknown as
      | LayoutEntry[]
      | null;
  }

  /**
   * The per-outlet resolved-layout record map. A thin seam over the core reader
   * so tests can stub it.
   */
  _resolvedLayouts(): Map<string, ResolvedLayoutRecord> {
    return _getResolvedLayouts() as unknown as Map<
      string,
      ResolvedLayoutRecord
    >;
  }

  /**
   * The provenance metadata for an outlet's resolved layout. A thin seam over
   * the blocks service so tests can stub it.
   */
  _resolvedLayoutMeta(
    outletName: string,
    options?: { ignoreSessionDraft?: boolean }
  ): ResolvedLayoutMeta | null {
    return this.blocks.resolvedLayoutMeta(outletName, options);
  }

  /**
   * The registered block class for a name. A thin seam over the blocks service
   * so tests can stub it.
   */
  _block(name: string): BlockRegistryEntry | undefined {
    return this.blocks.getBlock(name);
  }
}
