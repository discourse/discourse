// @ts-check
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trackedSet } from "@ember/reactive/collections";
import Service, { service } from "@ember/service";
import {
  entryKey,
  findAncestryPath,
  findEntry,
  findEntrySiblings,
  resolvePartDef,
  serializeEntryForSave,
} from "../lib/mutate-layout";
import { inferSchemaFromValues } from "../lib/schema-to-fields";

/**
 * Owns the editor's block-selection concern: the primary selection, the
 * multi-selection set, and every getter the inspector / outline / toolbar
 * derive from "what is selected right now".
 *
 * `selectBlock` is the event seam between this concern and the rest of the
 * editor. Cross-concern effects that used to live inline (flushing pending
 * arg edits, committing an in-flight in-session text edit, revealing the
 * selection into view) are not known here — they are registered by the
 * kernel as before/after hooks so this service never reaches up into the
 * editor that drives it. It injects only the revision beacon and the
 * layout-query service (both downward, dependency-free) — never the kernel.
 */
export default class WireframeSelectionService extends Service {
  @service wireframeRevision;
  @service wireframeLayoutQuery;
  @service wireframeSession;

  /**
   * The PRIMARY (anchor) selected block key — the block whose form the
   * inspector shows when exactly one is selected, and the anchor for
   * shift-range selection.
   */
  @tracked selectedBlockKey = null;

  /**
   * Snapshot of the selected block populated by either the canvas chrome
   * (on click) or the outline panel (on row click). The shape is a loose
   * subset of `{ key, name, id, args, containerArgs, conditions, outletArgs,
   * outletName, metadata }`. Some fields are only available from one entry
   * point — for example, `containerArgs` and `outletArgs` are only set when
   * the selection comes from a rendered block on the canvas.
   *
   * `args` here is the LIVE `entry.args` reference (a `trackedObject`); the
   * inspector reads through it so reads auto-track and edit-time mutations
   * are visible without us re-assigning `selectedBlockData`.
   */
  @tracked selectedBlockData = null;

  /**
   * The full set of selected block keys. `selectedBlockKey` is the PRIMARY
   * (anchor) of this set — the block whose form the inspector shows when
   * exactly one is selected, and the anchor for shift-range selection.
   * Single-select keeps this at `{ primaryKey }`; the outline's modifier
   * gestures grow it. `isBlockSelected` reads it, so the canvas highlights
   * every member. A `trackedSet`, so `.has` / `.size` reads auto-track.
   * Held private so consumers can't mutate the live set; reads go through
   * `selectionCount` / `selectedKeysSnapshot` / `isBlockSelected`.
   */
  #selectedKeys = trackedSet();

  /**
   * Callbacks fired at the start of `selectBlock`, BEFORE the selection
   * mutates — each receives `{ nextKey, prevKey }`. The kernel registers
   * its cross-concern pre-change effects here (flush pending args, commit
   * an in-flight in-session edit).
   *
   * @type {Array<Function>}
   */
  #beforeChange = [];

  /**
   * Callbacks fired at the end of `selectBlock`, AFTER the selection has
   * settled — each receives `{ key }` (the new primary key). The kernel
   * registers its cross-concern post-change effects here (reveal the
   * selection into view).
   *
   * @type {Array<Function>}
   */
  #afterChange = [];

  /**
   * Tracks the mousedown target so the deselect handler can require BOTH the
   * down and up events to land outside the allowed scope. Without this, dragging
   * to select text inside an input (mousedown on input, mouseup outside its
   * bounds) would synthesise a `click` on the common ancestor — often `<body>` —
   * and trigger an accidental deselect.
   *
   * @type {EventTarget|null}
   */
  #selectionMousedownTarget = null;
  #onCanvasMouseDown = (event) => {
    this.#selectionMousedownTarget = event.target;
  };

  /**
   * Document-level mouseup handler that clears the selection when BOTH the
   * mousedown and mouseup landed outside the allowed scope. Installed once at
   * construction and gated on `wireframeSession.active`, so it's a no-op outside
   * an editor session. Guards on `isDestroyed`/`isDestroying` (plain instance
   * flags, no service lookup) so a leaked listener firing after teardown bails.
   *
   * @param {MouseEvent} event
   */
  #onCanvasMouseUp = (event) => {
    const downTarget = this.#selectionMousedownTarget;
    this.#selectionMousedownTarget = null;
    if (this.isDestroyed || this.isDestroying) {
      return;
    }
    if (!this.wireframeSession.active || !this.selectedBlockKey) {
      return;
    }
    if (this.isInsideAllowedScope(downTarget)) {
      return;
    }
    if (this.isInsideAllowedScope(event.target)) {
      return;
    }
    this.selectBlock(null);
  };

  constructor() {
    super(...arguments);
    // Document-level so a click anywhere off the editor surface can deselect.
    // The handler self-gates on the session, so it's harmless while inactive;
    // removed on teardown (willDestroy) so it never leaks past the owner.
    document.addEventListener("mousedown", this.#onCanvasMouseDown);
    document.addEventListener("mouseup", this.#onCanvasMouseUp);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    document.removeEventListener("mousedown", this.#onCanvasMouseDown);
    document.removeEventListener("mouseup", this.#onCanvasMouseUp);
  }

  /**
   * Soft-failure metadata for the currently-selected block, or `null` if
   * the selection is healthy (or nothing is selected). Reads
   * `__failureType` / `__failureReason` written by the validator when
   * running in permissive mode — far more accurate than text-matching
   * the whole-outlet warning list against the selected block's name.
   *
   * @returns {{failureType: string, failureReason: string}|null}
   */
  get selectedBlockFailure() {
    // Republishes bump `structuralVersion`; in-place stamp clears
    // propagate via the per-entry `trackedObject` wrap (the
    // `entry.__failureType` read below opens a per-key dep).
    void this.wireframeRevision.version;
    const key = this.selectedBlockKey;
    if (!key) {
      return null;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
    const entry = located?.entry;
    if (!entry?.__failureType) {
      return null;
    }
    return {
      failureType: entry.__failureType,
      failureReason: entry.__failureReason ?? "",
    };
  }

  /**
   * Structured field-level errors for the selected block, keyed by arg
   * name. Each value is an array of `{ code, field, value?, expected? }`
   * details — permissive-mode validation accumulates every failure
   * inside an entry, so a field can carry multiple details in principle
   * (e.g. type + constraint).
   *
   * Details without a `field` are routed to `selectedBlockNonFieldErrors`
   * instead (the inspector lists them in the top pill, not under a
   * specific input).
   *
   * Drives FormKit's `addError` sync in the inspector — see
   * `inspector-form.gjs`.
   *
   * @returns {Object<string, Array<Object>>}
   */
  get selectedBlockFieldErrors() {
    void this.wireframeRevision.version;
    const key = this.selectedBlockKey;
    if (!key) {
      return {};
    }
    const entry = this.wireframeLayoutQuery.findEntryAndOutletSync(key)?.entry;
    const list = entry?.__failureDetails ?? [];
    const byField = {};
    for (const d of list) {
      if (!d?.field) {
        continue;
      }
      (byField[d.field] ??= []).push(d);
    }
    return byField;
  }

  /**
   * Structured errors for the selected block that aren't tied to a
   * single field — constraint violations, missing children, unknown
   * block, duplicate IDs, etc. These render in the top-of-inspector
   * pill since they have no specific control to hang under.
   *
   * @returns {Array<Object>}
   */
  get selectedBlockNonFieldErrors() {
    void this.wireframeRevision.version;
    const key = this.selectedBlockKey;
    if (!key) {
      return [];
    }
    const entry = this.wireframeLayoutQuery.findEntryAndOutletSync(key)?.entry;
    return (entry?.__failureDetails ?? []).filter((d) => !d?.field);
  }

  /**
   * Whether the selected block has any structured error (field-level
   * or not). Used by the inspector to decide whether to render the
   * compact errors pill.
   *
   * @returns {boolean}
   */
  get selectedBlockHasErrors() {
    return (
      Object.keys(this.selectedBlockFieldErrors).length > 0 ||
      this.selectedBlockNonFieldErrors.length > 0
    );
  }

  /**
   * Whether the selected block has a sibling above it. Drives the
   * `Move up` toolbar button's disabled state.
   *
   * @returns {boolean}
   */
  get canMoveSelectedUp() {
    return this.#selectionSiblingIndex() > 0;
  }

  /**
   * Whether the selected block has a sibling below it. Drives the
   * `Move down` toolbar button's disabled state.
   *
   * @returns {boolean}
   */
  get canMoveSelectedDown() {
    const idx = this.#selectionSiblingIndex();
    if (idx < 0) {
      return false;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(
      this.selectedBlockKey
    );
    if (!located) {
      return false;
    }
    const layout = this.wireframeLayoutQuery.readResolvedLayout(
      located.outletName
    );
    const sibs = findEntrySiblings(layout, this.selectedBlockKey);
    return sibs ? idx < sibs.siblings.length - 1 : false;
  }

  /**
   * Path of ancestor segments from the outlet root down to the
   * selected block. Used by the canvas-bottom breadcrumb. Each segment
   * carries `{key, blockName, displayName, isOutlet, outletName}`.
   * Outlet segment is first (`isOutlet: true`, `key: null`), nested
   * containers follow, selected block is last.
   *
   * @returns {Array<{key: string|null, blockName: string|null, displayName: string, isOutlet: boolean, outletName: string|null}>}
   */
  get selectedBlockAncestry() {
    // Read structuralVersion so this re-evaluates after every mutation.
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframeRevision.version;
    const key = this.selectedBlockKey;
    if (!key) {
      return [];
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return [];
    }
    const layout = this.wireframeLayoutQuery.readResolvedLayout(
      located.outletName
    );
    if (!layout) {
      return [];
    }
    const path = findAncestryPath(layout, key);
    if (!path) {
      return [];
    }
    return [
      {
        key: null,
        blockName: null,
        displayName: located.outletName,
        isOutlet: true,
        outletName: located.outletName,
      },
      ...path.map((entry) => {
        const meta = this.wireframeLayoutQuery.metadataFor(entry);
        const blockName =
          meta?.blockName ??
          (typeof entry.block === "string" ? entry.block : "(block)");
        return {
          key: entryKey(entry),
          blockName,
          displayName: meta?.shortName ?? blockName,
          isOutlet: false,
          outletName: located.outletName,
        };
      }),
    ];
  }

  /**
   * The selected entry's current serialised form, for the Raw JSON
   * inspector tab. Uses the same `serializeEntryForSave` that
   * `persistance` uses for the wire format — so what you see in the
   * Raw JSON tab matches what gets saved. Class references on
   * `entry.block` are normalised to their registered name strings,
   * and runtime-only fields (`__stableKey`, `__visible`, ...) are
   * dropped. Reads `structuralVersion` to refresh on every mutation.
   *
   * @returns {Object|null}
   */
  get selectedBlockRawEntry() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframeRevision.version;
    const key = this.selectedBlockKey;
    if (!key) {
      return null;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return null;
    }
    return serializeEntryForSave(located.entry);
  }

  /**
   * Live conditions tree for the currently-selected block. Re-resolves
   * the entry on every read so structural changes (publishes from
   * `updateSelectedConditions`, moves, etc.) are picked up automatically
   * by the condition builder's `@cached get tree()` via the
   * `structuralVersion` tracked dep.
   *
   * @returns {Array|Object|null}
   */
  get selectedBlockConditions() {
    // Force a tracked read so consumers re-render when structural
    // mutations re-publish.
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframeRevision.version;
    const key = this.selectedBlockKey;
    if (!key) {
      return null;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return this.selectedBlockData?.conditions ?? null;
    }
    return located.entry.conditions ?? null;
  }

  /** @returns {boolean} Whether more than one block is currently selected. */
  get hasMultiSelection() {
    return this.#selectedKeys.size > 1;
  }

  /** @returns {number} The number of blocks currently selected. */
  get selectionCount() {
    return this.#selectedKeys.size;
  }

  /**
   * Tells whether a given block key is part of the current selection. Reads the
   * `selectedKeys` set (not just the primary), so under a multi-selection every
   * selected block's chrome / outline row highlights. Used only for highlight;
   * identity checks (e.g. "is this the block being inline-edited") read
   * `selectedBlockKey` directly.
   *
   * @param {string|null} key - The composite block key (`${name}:${__stableKey}`).
   * @returns {boolean}
   */
  @action
  isBlockSelected(key) {
    return key != null && this.#selectedKeys.has(key);
  }

  /**
   * A frozen, read-only copy of the selected keys. Consumers that need the
   * full set (e.g. for a multi-delete) read this instead of the live set so
   * they can't mutate the selection out from under this service.
   *
   * @returns {ReadonlyArray<string>}
   */
  selectedKeysSnapshot() {
    return Object.freeze([...this.#selectedKeys]);
  }

  /**
   * The lock declaration for the currently-selected part, or null when the
   * selection isn't a part. `true` means the whole part is locked (no in-place
   * arg overrides); a string array lists the specific arg names that can't be
   * overridden in place. Drives the inspector's disabling of locked fields.
   *
   * @returns {true|string[]|null}
   */
  partLockForSelection() {
    const context = this.wireframeLayoutQuery.resolvePartContext(
      this.selectedBlockKey
    );
    if (!context) {
      return null;
    }
    return resolvePartDef(context.compositeEntry, context.idPath)?.lock ?? null;
  }

  /**
   * Selects a block as the PRIMARY (the inspector form + the multi-select
   * anchor). By default this also collapses the multi-selection to just this
   * block, so every existing caller stays single-select; the outline's
   * `toggleBlockSelection` / `setSelectionRange` pass `preserveMultiSelection`
   * to keep the surrounding set intact while moving the anchor.
   *
   * This is the event seam: it fires the registered before-change hooks
   * (with `{ nextKey, prevKey }`) before mutating, and the after-change hooks
   * (with `{ key }`) once the selection has settled.
   *
   * @param {Object|null} data - `{ key, ... }` (rest hydrated from the layout).
   * @param {{preserveMultiSelection?: boolean}} [options]
   */
  selectBlock(data, { preserveMultiSelection = false } = {}) {
    const nextKey = data?.key ?? null;
    const prevKey = this.selectedBlockKey;

    // Fire the before-change hooks so cross-concern effects (flush pending
    // arg edits, commit an in-flight in-session text edit) run before the
    // selection mutates and we apply stale state to the new block.
    for (const fn of this.#beforeChange) {
      fn({ nextKey, prevKey });
    }

    this.selectedBlockKey = nextKey;

    // Unless a multi-select gesture is moving the anchor within an existing
    // set, the primary IS the whole selection.
    if (!preserveMultiSelection) {
      this.#selectedKeys.clear();
      if (data?.key != null) {
        this.#selectedKeys.add(data.key);
      }
    }

    if (!data) {
      this.selectedBlockData = null;
      for (const fn of this.#afterChange) {
        fn({ key: this.selectedBlockKey });
      }
      return;
    }

    // Programmatic callers (drag-and-drop auto-select, command-palette,
    // tests) may pass only `{ key }`. Resolve the rest from the live layout
    // so the inspector has the block's real metadata. Without this the args
    // would round-trip through `inferSchemaFromValues` and richly-typed
    // controls (image, icon, color) would degrade to the generic "any" code
    // editor.
    const hydrated = this.#hydrateSelectionByKey(data);

    // Bind `args` to the LIVE `entry.args` (a `trackedObject`) so consumers
    // that need a live read (canvas-side, undo restoration, etc.) see
    // current values. Walks `_getResolvedLayouts()`, which returns the
    // resolved entry per outlet — so when session-drafts are active, we
    // bind to the draft entry, not the underlying layer's.
    const liveData = { ...hydrated };
    this.#bindLiveArgs(liveData);

    // Snapshot the args at selection time as a plain object. `argsSnapshot`
    // is what we hand to FormKit's `<Form @data>` — FormKit's immer-based
    // FKFormData rejects proxies, and reading `argsSnapshot` doesn't open
    // tracked deps on the underlying `entry.args` trackedObject. That keeps
    // the inspector's `values` getter from re-evaluating on every keystroke
    // (which would otherwise trigger Form's render path, costing the input
    // its focus).
    liveData.argsSnapshot = liveData.args ? { ...liveData.args } : {};

    // Same snapshot treatment for `containerArgs` — the inspector's
    // placement form takes the bag as `<Form @data>` and re-rendering it on
    // every keystroke would tear down inputs. We deep-snapshot one level
    // per namespace so each form sees a stable plain object.
    liveData.containerArgsSnapshot = liveData.containerArgs
      ? Object.fromEntries(
          Object.entries(liveData.containerArgs).map(([ns, bag]) => [
            ns,
            bag !== null && typeof bag === "object" ? { ...bag } : bag,
          ])
        )
      : {};

    // Resolve the parent's `childArgs` schema so the inspector can render
    // a placement section per namespace the parent declares.
    liveData.parentChildArgsSchema = this.#resolveParentChildArgsSchema(
      liveData.key
    );

    // Snapshot the parent's `args` so the inspector form can evaluate
    // `ui.conditional: { arg: "mode", equals: "grid" }` against the parent's
    // current mode. Bumping the structural version doesn't matter here
    // because changing the parent's mode strips this child's
    // `containerArgs.grid`, which forces a re-selection anyway.
    const parentEntry = this.wireframeLayoutQuery.findEntryParent(liveData.key);
    liveData.parentArgsSnapshot = parentEntry?.args
      ? { ...parentEntry.args }
      : {};

    // Whether the editor recognises this block type. Unregistered blocks have
    // no metadata, so the editor can't know their schema — the inspector shows
    // their values read-only rather than offering schema-less edits it can't
    // validate. Computed from the name (not the post-inference metadata, which
    // `#withInferredMetadata` populates with a synthetic schema below).
    liveData.isRegistered = liveData.name
      ? this.wireframeLayoutQuery.metadataForName(liveData.name) != null
      : true;

    // Augment metadata with an inferred args schema when the block didn't
    // declare one. We do this at selection time (not in the inspector form)
    // so the schema is a stable reference across the live keystroke session.
    // Without this, the inspector would re-compute its schema on every edit,
    // causing the FormKit `<form.Field>` components to remount — which would
    // tear down the input the user is typing in and trigger
    // "@name=... already in use" errors on rapid reselect.
    this.selectedBlockData = this.#withInferredMetadata(liveData);

    // Bring the freshly selected block into view (outline selection,
    // insert auto-select, undo/redo restore). No-ops when it's already
    // visible, so clicking a block on the canvas doesn't jolt the page.
    for (const fn of this.#afterChange) {
      fn({ key: this.selectedBlockKey });
    }
  }

  /**
   * Toggles a block in/out of the multi-selection (the outline's cmd/ctrl-click
   * gesture). Adding a block makes it the new primary; removing the primary
   * re-anchors to a remaining member (or clears the selection entirely).
   *
   * @param {Object} data - `{ key, ... }` for the toggled block.
   */
  toggleBlockSelection(data) {
    const key = data?.key;
    if (key == null) {
      return;
    }
    if (this.#selectedKeys.has(key)) {
      this.#selectedKeys.delete(key);
      if (this.selectedBlockKey === key) {
        // Re-anchor the primary to any remaining member so the inspector still
        // has a block to bind to (or clear when the set is now empty).
        const next = [...this.#selectedKeys][0] ?? null;
        this.selectBlock(next ? { key: next } : null, {
          preserveMultiSelection: true,
        });
      }
    } else {
      this.#selectedKeys.add(key);
      this.selectBlock(data, { preserveMultiSelection: true });
    }
  }

  /**
   * Replaces the multi-selection with `keys` and anchors the primary at
   * `anchorData` (the outline's shift-click range gesture).
   *
   * @param {Array<string>} keys - The block keys to select.
   * @param {Object} anchorData - `{ key, ... }` for the anchor (clicked) block.
   */
  setSelectionRange(keys, anchorData) {
    this.#selectedKeys.clear();
    for (const key of keys) {
      this.#selectedKeys.add(key);
    }
    this.selectBlock(anchorData, { preserveMultiSelection: true });
  }

  /**
   * Selects an outlet by selecting its implicit root `layout` block. The
   * selection then hydrates through the normal block path, so the inspector
   * surfaces the layout form (mode / gap / grid) for the outlet.
   *
   * @param {string} outletName
   */
  selectOutlet(outletName) {
    const key = this.wireframeLayoutQuery.outletRootKey(outletName);
    if (key) {
      this.selectBlock({ key });
    }
  }

  /**
   * Re-resolves the given block key against the current layout and rebinds
   * `selectedBlockKey` / `selectedBlockData`. If the key no longer exists,
   * clears the selection. Used after structural undo / redo to follow the
   * selection across layout snapshots.
   *
   * @param {string|null} blockKey
   */
  restoreSelection(blockKey) {
    if (!blockKey) {
      this.selectBlock(null);
      return;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(blockKey);
    if (!located) {
      this.selectBlock(null);
      return;
    }
    const blockName = this.wireframeLayoutQuery.blockNameOf(located.entry);
    const metadata = blockName
      ? this.wireframeLayoutQuery.metadataForName(blockName)
      : null;
    this.selectBlock({
      key: blockKey,
      name: blockName,
      args: located.entry.args,
      metadata,
      outletName: located.outletName,
      conditions: located.entry.conditions ?? null,
    });
  }

  /**
   * Clears the selection entirely WITHOUT firing the before/after hooks.
   * Used on editor `exit()` to tear the selection down — the hooks (flush
   * pending args, commit in-session edits, reveal-into-view) are
   * meaningless once the session is ending, and routing exit through
   * `selectBlock(null)` would fire them.
   */
  reset() {
    this.selectedBlockKey = null;
    this.selectedBlockData = null;
    this.#selectedKeys.clear();
  }

  /**
   * Whether `target` is inside an editor surface where a click must NOT
   * deselect — block chrome, the editor shell, the conditions floating panel,
   * or any Float-Kit portal (menus / modals / tooltips mount at body level,
   * outside the shell, but are conceptually part of the editor).
   *
   * @param {EventTarget} target
   * @returns {boolean}
   */
  isInsideAllowedScope(target) {
    if (!(target instanceof Element)) {
      return false;
    }
    return Boolean(
      target.closest(".wireframe-block-chrome") ||
      target.closest(".wireframe-shell") ||
      target.closest(".wireframe-conditions-floating-panel") ||
      target.closest(".fk-d-menu") ||
      target.closest(".fk-d-menu-modal") ||
      target.closest(".fk-d-tooltip__content")
    );
  }

  /**
   * Registers a callback fired at the start of every `selectBlock`, before
   * the selection mutates. Receives `{ nextKey, prevKey }`.
   *
   * @param {Function} fn
   */
  registerBeforeChange(fn) {
    this.#beforeChange.push(fn);
  }

  /**
   * Registers a callback fired at the end of every `selectBlock`, after the
   * selection has settled. Receives `{ key }` (the new primary key).
   *
   * @param {Function} fn
   */
  registerAfterChange(fn) {
    this.#afterChange.push(fn);
  }

  /**
   * @returns {number} the selected block's index among its siblings, or
   *   `-1` when nothing is selected / locatable.
   */
  #selectionSiblingIndex() {
    // Read `structuralVersion` so this getter re-evaluates after every
    // structural mutation — keeps the toolbar's move buttons reactive.
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframeRevision.version;
    const key = this.selectedBlockKey;
    if (!key) {
      return -1;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return -1;
    }
    const layout = this.wireframeLayoutQuery.readResolvedLayout(
      located.outletName
    );
    if (!layout) {
      return -1;
    }
    const sibs = findEntrySiblings(layout, key);
    return sibs?.index ?? -1;
  }

  /**
   * Fills in any selection fields that the caller didn't supply by resolving
   * the key against the current layout. A no-op when the caller already
   * passed full data (block-chrome's own click handler does, since it has
   * the entry in hand).
   *
   * @param {{key: string}} data
   * @returns {Object}
   */
  #hydrateSelectionByKey(data) {
    if (!data?.key) {
      return data;
    }
    const needsHydration =
      data.name == null || data.args == null || data.metadata == null;
    if (!needsHydration) {
      return data;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(data.key);
    if (!located) {
      return data;
    }
    const blockName =
      data.name ?? this.wireframeLayoutQuery.blockNameOf(located.entry);
    const metadata =
      data.metadata ??
      (blockName
        ? this.wireframeLayoutQuery.metadataForName(blockName)
        : null) ??
      null;
    return {
      ...data,
      name: blockName,
      args: data.args ?? located.entry.args,
      metadata,
      outletName: data.outletName ?? located.outletName,
      conditions: data.conditions ?? located.entry.conditions ?? null,
    };
  }

  /**
   * Resolves `data.key` against the registered layouts and rebinds `data.args`
   * to the live entry's `args` (a `trackedObject`). The `findEntry` walk is
   * synchronous when validation has already completed (which it has by the
   * time the user can click a block). On the rare path where validation is
   * still pending we leave `data.args` as-is — the inspector renders against
   * the snapshot the caller passed in, and the next mutation flush picks up
   * the live binding.
   */
  #bindLiveArgs(data) {
    if (!data?.key) {
      return;
    }
    const layoutMap = this.wireframeLayoutQuery._resolvedLayouts();
    for (const [, record] of layoutMap) {
      const layout = record.layout;
      if (!layout) {
        continue;
      }
      const found = findEntry(layout, data.key);
      if (found) {
        data.args = found.args;
        data.containerArgs = found.containerArgs ?? null;
        return;
      }
    }
  }

  /**
   * Resolves the parent block's `childArgs` schema for the selected entry,
   * so the inspector can render a placement section (one form per top-level
   * namespace declared by the parent). Returns `null` when the entry sits at
   * the outlet root or when the parent doesn't declare a childArgs schema.
   *
   * Handles both forms of `parent.block`: a class reference (decorated
   * blocks passed by class to `api.renderBlocks`) and a registered name
   * string (everything that's been through serialisation, including
   * theme-shipped layouts and the editor's own draft layer).
   *
   * @param {string} key
   * @returns {Object|null}
   */
  #resolveParentChildArgsSchema(key) {
    const parent = this.wireframeLayoutQuery.findEntryParent(key);
    if (!parent) {
      return null;
    }
    const parentName = this.wireframeLayoutQuery.blockNameOf(parent);
    if (!parentName) {
      return null;
    }
    return (
      this.wireframeLayoutQuery.metadataForName(parentName)?.childArgs ?? null
    );
  }

  /**
   * Returns `data` unchanged when its metadata already declares an arg schema.
   * Otherwise (no declared schema but the block has args) augments the metadata
   * with a schema inferred from the current arg values via `inferSchemaFromValues`.
   * Done at selection time, not in the inspector, so the schema is a stable
   * reference across the keystroke session — keeping the inspector's form fields
   * from remounting on every edit.
   *
   * @param {Object} data
   * @returns {Object}
   */
  #withInferredMetadata(data) {
    const declared = data.metadata?.args;
    if (declared && Object.keys(declared).length > 0) {
      return data;
    }
    const args = data.args ?? {};
    if (Object.keys(args).length === 0) {
      return data;
    }
    return {
      ...data,
      metadata: {
        ...(data.metadata ?? {}),
        args: inferSchemaFromValues(args),
      },
    };
  }
}
