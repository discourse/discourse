// @ts-check
import Service, { service } from "@ember/service";
import {
  _getResolvedLayout,
  _getResolvedLayouts,
  LAYOUT_SOURCE,
} from "discourse/blocks/block-outlet";
import { PART_KEY_SEGMENT } from "discourse/lib/blocks/-internals/composite";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import {
  entryKey,
  findAncestryPath,
  findEntry,
  findEntryByStableKey,
} from "../lib/mutate-layout";

/**
 * @typedef {import("discourse/blocks/block-outlet").LayoutEntry} LayoutEntry
 *   The canonical layout-entry shape (`block`, `id`, `args`, `children`,
 *   `containerArgs`, `__stableKey`, `__failure*`, …) owned by `block-outlet`.
 */

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
 * (`recordOutletRoot` / `clearOutletRoots`) the kernel drives.
 *
 * Kept un-cached on purpose: the resolved-layout reads feed off tracked sources
 * at call time, so a template binding re-runs when those layers change; caching
 * would freeze on an untracked early read.
 */
export default class WireframeLayoutQueryService extends Service {
  @service blocks;

  /**
   * Maps each drafted outlet to the composite key of its implicit root
   * `layout` block. Every drafted outlet is normalised to a single root
   * layout (see `wrapAsOutletRoot`); selecting that key is how the editor
   * "selects the outlet", and `isOutletRoot` consults this map to suppress
   * block-level affordances (move / duplicate / delete) on the root.
   *
   * Populated when the draft is materialised (the kernel calls
   * `recordOutletRoot`) and cleared on `exit`. Not persisted — the root key is
   * re-derived from the published draft each session.
   *
   * @type {Map<string, string>}
   */
  #outletRootKeys = new Map();

  /* Resolved-layout reads */

  /**
   * Returns the resolved layout array for an outlet, or null when no layout
   * is registered. Used by the persistence service to grab the snapshot of
   * an edited outlet that needs to be POSTed.
   *
   * Pass `ignoreSessionDraft: true` to resolve the underlying source's layout —
   * what is live now, apart from any unsaved edit. Reading both (with and without
   * the flag) yields the baseline and the edited layout for a change comparison.
   *
   * @param {string} outletName
   * @param {Object} [options]
   * @param {boolean} [options.ignoreSessionDraft=false] - When true, skip the session-draft layer and resolve the underlying source.
   * @returns {Array<LayoutEntry>|null}
   */
  readResolvedLayout(outletName, { ignoreSessionDraft = false } = {}) {
    return this._resolvedLayout(outletName, { ignoreSessionDraft });
  }

  /* Entry / outlet lookups */

  /**
   * Synchronous variant of `findEntryAndOutlet` — uses `record.layout`
   * (already-resolved) instead of awaiting `record.validatedLayout`. Drag
   * handlers fire after validation has long since completed, so the sync
   * lookup is safe and avoids forcing every call site to be async.
   *
   * @param {string} key
   * @returns {{entry: LayoutEntry, outletName: string}|null}
   */
  findEntryAndOutletSync(key) {
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
   * @param {string} key
   * @returns {LayoutEntry|null} The live entry, or `null` when no outlet resolves the key.
   */
  findEntryByKey(key) {
    return this.findEntryAndOutletSync(key)?.entry ?? null;
  }

  /**
   * Walks every registered outlet's resolved layout looking for the entry
   * whose composite key matches. Returns the live entry plus its containing
   * outlet name so the caller can both mutate `entry.args` in place AND
   * tell persistence which outlet just got dirty.
   *
   * @param {string} key
   * @returns {Promise<{entry: LayoutEntry, outletName: string}|null>}
   */
  async findEntryAndOutlet(key) {
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
   *
   * @param {string} blockKey
   * @returns {LayoutEntry|null}
   */
  findEntryParent(blockKey) {
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
   *
   * @param {string} ancestorKey
   * @param {string} descendantKey
   * @returns {boolean}
   */
  isAncestorOf(ancestorKey, descendantKey) {
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
   *
   * @param {string} key
   * @returns {{compositeEntry: LayoutEntry, compositeKey: string, outletName: string, idPath: string[], partPath: string}|null}
   */
  resolvePartContext(key) {
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
   *
   * @param {LayoutEntry} entry
   * @returns {string|null}
   */
  blockNameOf(entry) {
    if (!entry?.block) {
      return null;
    }
    if (typeof entry.block === "string") {
      return entry.block;
    }
    return this.metadataFor(entry)?.blockName ?? null;
  }

  /**
   * @param {LayoutEntry} entry
   * @returns {Object|null}
   */
  metadataFor(entry) {
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
   *
   * @param {string} blockName
   * @returns {Object|null}
   */
  metadataForName(blockName) {
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
   *
   * @param {string|Function} blockRef
   * @returns {Object|null}
   */
  lookupBlockMetadata(blockRef) {
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
   *
   * @param {string|Function} blockRef
   * @returns {string|null}
   */
  lookupBlockDisplayName(blockRef) {
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
   * @param {string} outletName
   * @returns {string} One of `OUTLET_STATE`.
   */
  outletState(outletName) {
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
   *
   * @param {string} outletName
   * @returns {boolean}
   */
  isOutletEditable(outletName) {
    return this.outletState(outletName) !== OUTLET_STATE.LOCKED;
  }

  /* Grid predicates */

  /**
   * Whether the entry is a `wf:layout` in per-cell `grid` mode. Accepts
   * the legacy `"free-grid"` mode value as an alias so existing saved
   * layouts (pre-rename) keep working.
   *
   * @param {LayoutEntry|null} entry
   * @returns {boolean}
   */
  isGridContainer(entry) {
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
   *
   * @param {LayoutEntry|null} entry
   * @returns {boolean}
   */
  isGridCellEntry(entry) {
    return entry?.containerArgs?.grid != null;
  }

  /**
   * Whether `entry` is a grid-cell occupant whose direct parent is the
   * layout identified by `gridKey`. Used by the grid manipulator to tell a
   * same-grid source (re-placed in situ) from one arriving from elsewhere.
   *
   * @param {LayoutEntry} entry
   * @param {string} gridKey
   * @returns {boolean}
   */
  isCellInGrid(entry, gridKey) {
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
   *
   * @param {string} blockKey
   * @returns {boolean}
   */
  isComposedComposite(blockKey) {
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
   *
   * @param {string} outletName
   */
  recordOutletRoot(outletName) {
    const root = this.readResolvedLayout(outletName)?.[0];
    if (root) {
      this.#outletRootKeys.set(outletName, entryKey(root));
    }
  }

  /**
   * The composite key of an outlet's implicit root `layout` block, or `null`
   * when the outlet hasn't been drafted yet.
   *
   * @param {string} outletName
   * @returns {string|null}
   */
  outletRootKey(outletName) {
    return this.#outletRootKeys.get(outletName) ?? null;
  }

  /**
   * Whether `key` identifies an outlet's implicit root `layout` block. The
   * chrome and inspector consult this to present the root AS the outlet —
   * suppressing block-level affordances (move / duplicate / delete) that
   * don't apply to a page region.
   *
   * @param {string|null} key
   * @returns {boolean}
   */
  isOutletRoot(key) {
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
  clearOutletRoots() {
    this.#outletRootKeys.clear();
  }

  /**
   * Best-effort lookup of the outlet name that owns `entry`. Walks the
   * currently-resolved layout map; returns null when the entry is no longer
   * present (e.g. it's been moved out of every published layer). Used by
   * `resetAll` to decide which arg-snapshots to drop after a structural
   * rollback.
   *
   * @param {LayoutEntry} entry
   * @returns {string|null}
   */
  outletForEntry(entry) {
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
   *
   * @param {string|Function} blockRef
   * @returns {string|null}
   */
  #blockNameFor(blockRef) {
    if (typeof blockRef === "string") {
      return blockRef;
    }
    return getBlockMetadata(blockRef)?.blockName ?? null;
  }

  /**
   * @param {Array<LayoutEntry>} layout
   * @param {LayoutEntry} target
   * @returns {boolean}
   */
  #layoutContainsEntry(layout, target) {
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
   *
   * @param {string} outletName
   * @param {{ignoreSessionDraft?: boolean}} [options]
   * @returns {Array<LayoutEntry>|null}
   */
  _resolvedLayout(outletName, options) {
    return _getResolvedLayout(outletName, options);
  }

  /**
   * The per-outlet resolved-layout record map. A thin seam over the core reader
   * so tests can stub it.
   *
   * @returns {Map<string, Object>}
   */
  _resolvedLayouts() {
    return _getResolvedLayouts();
  }

  /**
   * The provenance metadata for an outlet's resolved layout. A thin seam over
   * the blocks service so tests can stub it.
   *
   * @param {string} outletName
   * @param {{ignoreSessionDraft?: boolean}} [options]
   * @returns {Object|null}
   */
  _resolvedLayoutMeta(outletName, options) {
    return this.blocks.resolvedLayoutMeta(outletName, options);
  }

  /**
   * The registered block class for a name. A thin seam over the blocks service
   * so tests can stub it.
   *
   * @param {string} name
   * @returns {Function|null}
   */
  _block(name) {
    return this.blocks.getBlock(name);
  }
}
