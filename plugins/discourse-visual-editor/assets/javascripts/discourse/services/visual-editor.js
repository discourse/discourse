// @ts-check
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import {
  trackedArray,
  trackedMap,
  trackedSet,
} from "@ember/reactive/collections";
import Service, { service } from "@ember/service";
import {
  _clearLayoutLayer,
  _getOutletLayouts,
  _setLayoutLayer,
  LAYOUT_LAYERS,
} from "discourse/blocks/block-outlet";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import discourseDebounce from "discourse/lib/debounce";
import PreloadStore from "discourse/lib/preload-store";
import {
  cloneLayoutForDraft,
  findEntry,
  insertEntryAt,
  moveEntry,
  removeEntry,
} from "../lib/mutate-layout";
import { inferSchemaFromValues } from "../lib/schema-to-fields";

const FLUSH_DELAY_MS = 200;

/**
 * Phase 1 + 2 + 3 editor service. Holds the editor's session state and
 * mediates the in-memory mutation pipeline.
 *
 * Reactivity contract: every `@tracked` field on this service is read by the
 * panels and the canvas chrome. Mutating one re-renders the relevant pieces
 * via Glimmer's tracking system without manual notification.
 *
 * Mutation pipeline: at `enter()`, the editor deep-clones every outlet's
 * resolved layout and publishes those clones as the `session-draft` layer
 * (highest precedence in the block resolution chain). Edits during the
 * session mutate the draft entry's `args` (a `trackedObject`) directly —
 * the curried block reads through reactive getters defined by
 * `createBlockArgsWithReactiveGetters`, so a single `entry.args.title = "x"`
 * propagates to that block's specific text node without re-rendering the
 * layout structure or remounting the inspector form.
 *
 * Eager-on-enter (rather than lazy-on-first-edit) is the key trick: the
 * one-time layout-reference swap happens when the user clicks "Edit page",
 * which is a moment they expect a state transition. After that, no layer
 * switches happen until exit, so the canvas stays stable through every
 * keystroke.
 *
 * Discard / exit clears every session-draft layer the editor materialised,
 * leaving the underlying theme / code-default layers intact. Persistence
 * (Phase 3d) publishes the saved layout to the `theme` layer silently —
 * the session-draft is still resolved at that point, so the page doesn't
 * re-render at save time.
 */
export default class VisualEditorService extends Service {
  @service blocks;
  @service currentUser;
  @service site;
  @service siteSettings;

  @tracked isActive = false;
  @tracked selectedBlockKey = null;

  /**
   * The id of the theme this editor session is bound to. Set on `enter()`
   * — explicit `themeId` argument takes precedence; otherwise we fall back
   * to whichever user-selectable theme is marked default on the site. The
   * persistence service uses this when posting saves; if it remains null,
   * the toolbar's Save button stays disabled.
   *
   * Phase 3f wires the URL-based theme chooser to set this via
   * `enter({ themeId })` so admins picking a theme from the admin show page
   * land here with the right target.
   *
   * @type {number|null}
   */
  @tracked activeThemeId = null;

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
   * Monotonically increasing counter bumped on every structural mutation.
   * Consumers (the outline panel, future condition evaluators) read it to
   * open a tracked dep that fires *every* mutation — `_structurallyEdited
   * Outlets.size` only changes on the *first* mutation per outlet, so it
   * isn't enough on its own.
   *
   * @type {number}
   */
  @tracked structuralVersion = 0;
  /**
   * Drag-and-drop session state. Set when the user grabs a block via
   * `editor-draggable`; cleared when the drag ends (success or cancel).
   *
   * `dragSourceKey` opens body-class `--ve-dragging` so the canvas can
   * surface drop zones via CSS. `activeDropTarget` carries the most recent
   * `onDragEnter` payload so the corresponding zone can render its hover
   * styling without each zone needing its own listener.
   *
   * @type {string|null}
   */
  @tracked dragSourceKey = null;
  /** @type {string|null} */
  @tracked dragSourceOutlet = null;
  /** @type {{targetKey: string, position: string, outletName: string}|null} */
  @tracked activeDropTarget = null;
  /**
   * Undo / redo stacks for in-memory edits. Each entry captures one batch of
   * arg mutations: the affected entry, plus a `Map` of `argName → previous
   * value`. Undo restores by writing the previous values back; redo flips
   * back to the post-batch values.
   *
   * @type {Array<{entry: Object, prev: Map<string, *>, next: Map<string, *>}>}
   */
  _undoStack = trackedArray();

  /** @type {Array<{entry: Object, prev: Map<string, *>, next: Map<string, *>}>} */
  _redoStack = trackedArray();

  /**
   * For each entry we've ever mutated, the `entry.args` snapshot taken
   * before the first mutation. Reset / exit walk this map and write those
   * snapshots back into `entry.args`.
   *
   * Stored as a `trackedMap` so reads of `.size` (used by `isDirty`) open
   * a tracked dependency on the collection — that's what keeps the toolbar's
   * Save / Reset buttons reactive to the very first edit.
   *
   * @type {Map<Object, Map<string, *>>}
   */
  _initialSnapshots = trackedMap();

  /**
   * Pending arg changes for the currently-selected block, accumulated across
   * a burst of keystrokes and flushed by `_flushPendingArgs` after a short
   * idle delay. Keys are arg names; values are the latest value typed.
   *
   * @type {Map<string, *>}
   */
  _pendingArgs = new Map();

  /**
   * Outlets where this editor session has materialised a `session-draft`
   * layer. Tracked here (rather than re-derived from the block-outlet
   * record) so `exit` clears exactly what the editor published without
   * touching drafts produced elsewhere.
   *
   * @type {Set<string>}
   */
  _draftedOutlets = new Set();

  /**
   * Names of every outlet whose draft layer has at least one in-memory
   * mutation. Persistence iterates this set on Save to know which outlet
   * layouts to POST. Cleared per-outlet by the persistence service after a
   * successful save, and wholesale on `exit` / `resetAll`.
   *
   * @type {Set<string>}
   */
  _editedOutlets = new Set();

  /**
   * Pristine clones of every drafted outlet's layout, captured at `enter()`
   * time. Used by `resetAll()` to roll structural mutations (drag/drop,
   * insert, delete in later phases) back to the page's pre-edit state.
   *
   * Stored as a separate clone from the draft itself so subsequent edits
   * (which mutate the draft in place) never bleed into the snapshot.
   *
   * @type {Map<string, Array<Object>>}
   */
  _originalLayouts = new Map();

  /**
   * Outlets whose draft has at least one structural mutation (block moved,
   * inserted, deleted). A `trackedSet` so the toolbar's `isDirty` getter
   * reactively responds to the first move — equivalent role to
   * `_initialSnapshots` for arg edits.
   *
   * @type {Set<string>}
   */
  _structurallyEditedOutlets = trackedSet();

  /**
   * Whether the current user is allowed to use the editor. Staff are always
   * allowed. Non-staff users must belong to at least one of the groups listed
   * in the `visual_editor_allowed_groups` site setting. The plugin must also
   * be enabled via `visual_editor_enabled`.
   *
   * @returns {boolean}
   */
  get canEdit() {
    if (!this.siteSettings.visual_editor_enabled) {
      return false;
    }
    if (!this.currentUser) {
      return false;
    }
    if (this.currentUser.staff) {
      return true;
    }
    // Group-list site settings serialize as a pipe-delimited string of
    // group ids ("1|11|41"). Empty values produce empty strings, hence the
    // filter to drop them.
    const allowed = (this.siteSettings.visual_editor_allowed_groups || "")
      .split("|")
      .filter(Boolean);
    if (allowed.length === 0) {
      return false;
    }
    const userGroupIds = (this.currentUser.groups || []).map((g) =>
      String(g.id)
    );
    return allowed.some((id) => userGroupIds.includes(String(id)));
  }

  /**
   * The names of every block outlet that has a layout registered right now.
   * The entry pill uses this to decide whether to appear and what count to
   * display. Sourced from `services/blocks` so the registry is the single
   * source of truth.
   *
   * @returns {string[]}
   */
  get editableOutlets() {
    return this.blocks
      .listOutlets()
      .filter((name) => this.blocks.hasLayout(name));
  }

  @action
  enter({ themeId } = {}) {
    if (!this.canEdit) {
      return;
    }
    this.isActive = true;
    this.activeThemeId = themeId ?? this._defaultThemeId();
    document.body.classList.add("visual-editor-active");
    this._materializeAllDrafts();
  }

  /**
   * Picks a default theme id for editor sessions that didn't supply one.
   * Reads from the `activatedThemes` preload — the server-resolved active
   * theme stack for this request, ordered parent-first by
   * `Theme.transform_ids`. The first id is the parent theme (the one the
   * page is actually rendering against), which is exactly what we want to
   * save edits to.
   *
   * Falls back to the user-selectable themes list when activatedThemes is
   * unavailable (legacy preload format) or empty. Returns null when no
   * themes are available, in which case the Save button stays disabled.
   *
   * @returns {number|null}
   */
  _defaultThemeId() {
    const activated = PreloadStore.get("activatedThemes");
    if (activated && typeof activated === "object") {
      const ids = Object.keys(activated)
        .map((id) => parseInt(id, 10))
        .filter((id) => Number.isFinite(id) && id > 0);
      if (ids.length > 0) {
        return ids[0];
      }
    }
    const themes = this.site?.user_themes ?? [];
    return (
      themes.find((t) => t.default)?.theme_id ?? themes[0]?.theme_id ?? null
    );
  }

  /**
   * Eagerly publishes a `session-draft` layer for every outlet that has a
   * resolved layout. After this runs, `_getOutletLayouts()` returns draft
   * entries for those outlets — the rest of the editor session mutates
   * those drafts in place via `trackedObject`, so no further layer swap
   * happens during typing.
   *
   * Idempotent: running over already-drafted outlets is a no-op (skipped by
   * the `_draftedOutlets` check). Invoked from `enter()`.
   */
  _materializeAllDrafts() {
    for (const outletName of this.editableOutlets) {
      if (this._draftedOutlets.has(outletName)) {
        continue;
      }
      const layout = this.readResolvedLayout(outletName);
      if (!layout) {
        continue;
      }
      const draftLayout = cloneLayoutForDraft(layout);
      // Second clone, never published. Held as the rollback target for
      // `resetAll()` — we can't capture the draft itself because in-place
      // arg mutations would leak into the snapshot.
      this._originalLayouts.set(outletName, cloneLayoutForDraft(layout));
      _setLayoutLayer(
        outletName,
        LAYOUT_LAYERS.SESSION_DRAFT,
        draftLayout,
        getOwner(this)
      );
      this._draftedOutlets.add(outletName);
    }
  }

  @action
  exit() {
    // Roll back any in-memory mutations recorded in initial snapshots. With
    // session-drafts active, the underlying entries weren't actually
    // mutated, so this is effectively a no-op for the production path
    // (we're about to drop the drafts anyway). For test paths that bypass
    // `enter()` and mutate code-default entries directly, this restores
    // them so test isolation holds.
    for (const [entry, snapshot] of this._initialSnapshots) {
      this._writeArgs(entry, snapshot);
    }

    // Clear session-drafts. The underlying theme/code-default layer becomes
    // resolved again, displaying whatever was there before the editor
    // opened — in-memory mutations live ONLY on draft entries, so dropping
    // the drafts discards the mutations cleanly.
    for (const outletName of this._draftedOutlets) {
      _clearLayoutLayer(outletName, LAYOUT_LAYERS.SESSION_DRAFT);
    }
    this._draftedOutlets.clear();

    this.isActive = false;
    this.activeThemeId = null;
    this.selectedBlockKey = null;
    this.selectedBlockData = null;
    this.dragSourceKey = null;
    this.dragSourceOutlet = null;
    this.activeDropTarget = null;
    this._undoStack.length = 0;
    this._redoStack.length = 0;
    this._initialSnapshots.clear();
    this._pendingArgs.clear();
    this._editedOutlets.clear();
    this._originalLayouts.clear();
    this._structurallyEditedOutlets.clear();
    document.body.classList.remove("visual-editor-active");
  }

  /** @returns {boolean} */
  get canUndo() {
    return this._undoStack.length > 0;
  }

  /** @returns {boolean} */
  get canRedo() {
    return this._redoStack.length > 0;
  }

  /** @returns {boolean} */
  get isDirty() {
    return (
      this._initialSnapshots.size > 0 ||
      this._structurallyEditedOutlets.size > 0
    );
  }

  /** @returns {boolean} */
  get isDragging() {
    return this.dragSourceKey != null;
  }

  @action
  toggle() {
    if (this.isActive) {
      this.exit();
    } else {
      this.enter();
    }
  }

  @action
  selectBlock(data) {
    // Flush anything still pending from a previous selection so we don't
    // apply those keystrokes to the new block by accident.
    if (this._pendingArgs.size > 0) {
      this._flushPendingArgs();
    }
    this.selectedBlockKey = data?.key ?? null;

    if (!data) {
      this.selectedBlockData = null;
      return;
    }

    // Bind `args` to the LIVE `entry.args` (a `trackedObject`) so consumers
    // that need a live read (canvas-side, undo restoration, etc.) see
    // current values. Walks `_getOutletLayouts()`, which returns the
    // resolved entry per outlet — so when session-drafts are active, we
    // bind to the draft entry, not the underlying layer's.
    const liveData = { ...data };
    this._bindLiveArgs(liveData);

    // Snapshot the args at selection time as a plain object. `argsSnapshot`
    // is what we hand to FormKit's `<Form @data>` — FormKit's immer-based
    // FKFormData rejects proxies, and reading `argsSnapshot` doesn't open
    // tracked deps on the underlying `entry.args` trackedObject. That keeps
    // the inspector's `values` getter from re-evaluating on every keystroke
    // (which would otherwise trigger Form's render path, costing the input
    // its focus).
    liveData.argsSnapshot = liveData.args ? { ...liveData.args } : {};

    // Augment metadata with an inferred args schema when the block didn't
    // declare one. We do this at selection time (not in the inspector form)
    // so the schema is a stable reference across the live keystroke session.
    // Without this, the inspector would re-compute its schema on every edit,
    // causing the FormKit `<form.Field>` components to remount — which would
    // tear down the input the user is typing in and trigger
    // "@name=... already in use" errors on rapid reselect.
    this.selectedBlockData = this._withInferredMetadata(liveData);
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
  _bindLiveArgs(data) {
    if (!data?.key) {
      return;
    }
    const layoutMap = _getOutletLayouts();
    for (const [, record] of layoutMap) {
      const layout = record.layout;
      if (!layout) {
        continue;
      }
      const found = findEntry(layout, data.key);
      if (found) {
        data.args = found.args;
        return;
      }
    }
  }

  _withInferredMetadata(data) {
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

  /**
   * Tells whether a given block key matches the current selection.
   *
   * Decorated with `@action` so that Glimmer template subexpressions like
   * `(this.visualEditor.isBlockSelected row.blockKey)` keep the correct
   * `this` binding. Without it Glimmer extracts the bare function reference
   * and calls it without context, which throws when the body reads
   * `this.selectedBlockKey`.
   *
   * @param {string|null} key - The composite block key (`${name}:${__stableKey}`).
   * @returns {boolean}
   */
  @action
  isBlockSelected(key) {
    return this.selectedBlockKey != null && this.selectedBlockKey === key;
  }

  /**
   * Records a pending arg change for the currently-selected block and
   * schedules a debounced flush. A burst of keystrokes within
   * `FLUSH_DELAY_MS` collapses into a single batch — applied to
   * `entry.args` at flush time. Because `entry.args` is a `trackedObject`
   * and the curried block reads through reactive getters, the canvas
   * updates without re-rendering anything else.
   *
   * @param {string} argName
   * @param {*} value
   */
  @action
  updateSelectedArg(argName, value) {
    if (!this.selectedBlockKey) {
      return;
    }
    this._pendingArgs.set(argName, value);
    discourseDebounce(this, this._flushPendingArgs, FLUSH_DELAY_MS);
  }

  /**
   * Applies every pending arg change in one shot by mutating the resolved
   * entry's `args` directly. The block's reactive getters propagate the
   * change through Glimmer's autotracking — no layout swap, no DOM
   * tear-down, no inspector remount.
   *
   * Captures the pre-edit snapshot BEFORE applying the mutation so reset /
   * exit / undo have the original state to restore. Records the affected
   * outlet in `_editedOutlets` so persistence knows what to POST on Save.
   *
   * @returns {Promise<boolean>} True if the flush touched an entry.
   */
  async _flushPendingArgs() {
    const key = this.selectedBlockKey;
    if (!key || this._pendingArgs.size === 0) {
      return false;
    }
    const pending = [...this._pendingArgs.entries()];
    this._pendingArgs.clear();

    const located = await this._findEntryAndOutlet(key);
    if (!located) {
      return false;
    }
    const { entry, outletName } = located;
    this._editedOutlets.add(outletName);

    const prev = new Map();
    for (const [argName] of pending) {
      prev.set(argName, entry.args?.[argName]);
    }

    // Capture the FULL pre-edit snapshot before applying mutations so
    // reset / exit have a complete picture of what to roll back to. Doing
    // this after the mutation would capture the post-edit state and make
    // rollback a no-op.
    this._captureInitialSnapshot(entry, prev);

    const next = new Map();
    for (const [argName, value] of pending) {
      next.set(argName, value);
      entry.args[argName] = value;
    }

    this._undoStack.push({ entry, prev, next });
    this._redoStack.length = 0;

    return true;
  }

  /**
   * Reverts the most recent mutation by writing the captured `prev` values
   * back into `entry.args`. The redo stack picks up the post-batch state so
   * a subsequent `redo()` can re-apply the burst.
   *
   * @returns {Promise<boolean>}
   */
  @action
  async undo() {
    if (!this.canUndo) {
      return false;
    }
    const batch = this._undoStack.pop();
    this._writeArgs(batch.entry, batch.prev);
    this._redoStack.push(batch);
    return true;
  }

  /**
   * Re-applies the most recently undone mutation. Mirror image of `undo()`.
   *
   * @returns {Promise<boolean>}
   */
  @action
  async redo() {
    if (!this.canRedo) {
      return false;
    }
    const batch = this._redoStack.pop();
    this._writeArgs(batch.entry, batch.next);
    this._undoStack.push(batch);
    return true;
  }

  /**
   * Restores every touched outlet back to the pristine layout captured at
   * `enter()` (structural edits) and every touched entry back to its initial
   * (pre-edit) args (arg edits).
   *
   * For outlets that had structural mutations, we re-publish the captured
   * `_originalLayouts` clone — that's a fresh tree, so the draft layer's
   * entries get fully replaced. We then skip the per-entry args restoration
   * for those outlets because the new draft already carries pristine args
   * (the structurally-reset entries are the ones from `_originalLayouts`,
   * never mutated). Args-only outlets fall through to the existing
   * `_initialSnapshots` write-back path.
   *
   * @returns {Promise<boolean>}
   */
  @action
  async resetAll() {
    if (!this.isDirty) {
      return false;
    }

    // Wholesale re-publish of pristine layouts replaces every draft entry,
    // invalidating the per-entry references stored in `_initialSnapshots`
    // for those outlets — drop them so we don't try to mutate stale entries.
    const structurallyResetOutlets = new Set(this._structurallyEditedOutlets);
    if (structurallyResetOutlets.size > 0) {
      for (const outletName of structurallyResetOutlets) {
        const original = this._originalLayouts.get(outletName);
        if (!original) {
          continue;
        }
        // Clone again: the snapshot must remain pristine in case the user
        // mutates and then resets a second time during the same session.
        _setLayoutLayer(
          outletName,
          LAYOUT_LAYERS.SESSION_DRAFT,
          cloneLayoutForDraft(original),
          getOwner(this)
        );
      }
      // Drop arg-snapshots whose entries belong to structurally-reset outlets.
      // Entries elsewhere keep their snapshots so the args path still works.
      for (const [entry] of this._initialSnapshots) {
        if (structurallyResetOutlets.has(this._outletForEntry(entry))) {
          this._initialSnapshots.delete(entry);
        }
      }
    }

    // Args-only restoration for whatever survived the structural pass.
    for (const [entry, snapshot] of this._initialSnapshots) {
      this._writeArgs(entry, snapshot);
    }
    this._undoStack.length = 0;
    this._redoStack.length = 0;
    this._initialSnapshots.clear();
    this._structurallyEditedOutlets.clear();
    this._editedOutlets.clear();
    return true;
  }

  /**
   * Best-effort lookup of the outlet name that owns `entry`. Walks the
   * currently-resolved layout map; returns null when the entry is no longer
   * present (e.g. it's been moved out of every published layer). Used by
   * `resetAll` to decide which arg-snapshots to drop after a structural
   * rollback.
   *
   * @param {Object} entry
   * @returns {string|null}
   */
  _outletForEntry(entry) {
    const layoutMap = _getOutletLayouts();
    for (const [outletName, record] of layoutMap) {
      if (record.layout && this._layoutContainsEntry(record.layout, entry)) {
        return outletName;
      }
    }
    return null;
  }

  _layoutContainsEntry(layout, target) {
    for (const entry of layout) {
      if (entry === target) {
        return true;
      }
      if (
        entry.children?.length &&
        this._layoutContainsEntry(entry.children, target)
      ) {
        return true;
      }
    }
    return false;
  }

  /**
   * Writes a `Map<argName, value>` of arg values into `entry.args`. Used by
   * undo, redo, and reset. Each assignment goes through the `trackedObject`
   * proxy so reactive readers re-evaluate.
   */
  _writeArgs(entry, args) {
    if (!entry?.args) {
      return;
    }
    for (const [argName, value] of args) {
      if (value === undefined) {
        delete entry.args[argName];
      } else {
        entry.args[argName] = value;
      }
    }
  }

  /**
   * Captures an entry's pre-edit args the FIRST time it's about to be
   * mutated, so `resetAll()` has a stable target regardless of how many
   * later edits we apply on top. Caller MUST invoke this BEFORE applying
   * the mutation — otherwise the snapshot captures the post-edit state.
   */
  _captureInitialSnapshot(entry, prev) {
    if (this._initialSnapshots.has(entry)) {
      return;
    }
    // Snapshot the entire pre-edit args object so reset is a true
    // round-trip even when later batches edit different keys. The `prev`
    // map is layered in for any keys it carries that aren't already in
    // the snapshot — defensive, since `prev` is built from `entry.args`
    // reads in the same critical section.
    const fullSnapshot = new Map();
    for (const [k, v] of Object.entries(entry.args ?? {})) {
      fullSnapshot.set(k, v);
    }
    for (const [k, v] of prev) {
      if (!fullSnapshot.has(k)) {
        fullSnapshot.set(k, v);
      }
    }
    this._initialSnapshots.set(entry, fullSnapshot);
  }

  /**
   * Walks every registered outlet's resolved layout looking for the entry
   * whose composite key matches. Returns the live entry plus its containing
   * outlet name so the caller can both mutate `entry.args` in place AND
   * tell persistence which outlet just got dirty.
   *
   * @param {string} key
   * @returns {Promise<{entry: Object, outletName: string}|null>}
   */
  async _findEntryAndOutlet(key) {
    const layoutMap = _getOutletLayouts();
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
   * Returns the resolved layout array for an outlet, or null when no layout
   * is registered. Used by the persistence service to grab the snapshot of
   * an edited outlet that needs to be POSTed.
   *
   * @param {string} outletName
   * @returns {Array<Object>|null}
   */
  readResolvedLayout(outletName) {
    return _getOutletLayouts().get(outletName)?.layout ?? null;
  }

  /**
   * Records the start of a drag. The `editor-draggable` modifier feeds this
   * via its `onDragStart` callback. The body class lights up the canvas's
   * drop-zone CSS (zones are `display: none` until the body has the class).
   *
   * @param {{blockKey: string, outletName: string}} payload
   */
  @action
  startDrag({ blockKey, outletName }) {
    this.dragSourceKey = blockKey;
    this.dragSourceOutlet = outletName;
    document.body.classList.add("visual-editor-dragging");
  }

  /**
   * Resets drag state regardless of whether the drag completed in a drop or
   * was cancelled. The `editor-draggable` modifier always fires `onDrop`
   * (Pragmatic dnd's nomenclature — "drop" includes the cancelled case
   * where `location.current.dropTargets` is empty), so this is the single
   * cleanup point.
   */
  @action
  endDrag() {
    this.dragSourceKey = null;
    this.dragSourceOutlet = null;
    this.activeDropTarget = null;
    document.body.classList.remove("visual-editor-dragging");
  }

  /**
   * Highlights a drop zone as the dragged block hovers over it. The shell
   * reads `activeDropTarget` and applies a `--active` class to the matching
   * zone — keeps the per-zone modifier instances stateless.
   *
   * @param {{targetKey: string, position: string, outletName: string}} target
   */
  @action
  setActiveDropTarget(target) {
    this.activeDropTarget = target;
  }

  /**
   * Clears the active drop-zone highlight when the cursor leaves it. We
   * compare `targetKey` so a stale `dragLeave` from a zone we already moved
   * away from doesn't wipe the highlight on the *current* zone.
   *
   * @param {{targetKey: string, position: string}} target
   */
  @action
  clearActiveDropTarget(target) {
    if (
      this.activeDropTarget?.targetKey === target.targetKey &&
      this.activeDropTarget?.position === target.position
    ) {
      this.activeDropTarget = null;
    }
  }

  /**
   * Tells whether dropping the currently-dragged block at `target` is
   * compatible with the system's authorization rules (`allowedOutlets` /
   * `deniedOutlets` declared on the block class). Same-outlet moves always
   * pass; cross-outlet moves consult the block's metadata.
   *
   * Returns true when no source key is set (no drag in progress) — keeps
   * `canDrop` calls cheap during normal operation.
   *
   * @param {{targetOutletName: string}} target
   * @returns {boolean}
   */
  canDropAt({ targetOutletName }) {
    if (!this.dragSourceKey) {
      return true;
    }
    if (!targetOutletName || targetOutletName === this.dragSourceOutlet) {
      return true;
    }
    const sourceEntry = this._findEntryByKey(this.dragSourceKey);
    if (!sourceEntry) {
      return false;
    }
    const metadata = this._metadataFor(sourceEntry);
    if (!metadata) {
      // No metadata = block class isn't registered. Be permissive — the
      // server-side validator will catch it on save if it really is broken.
      return true;
    }
    if (
      metadata.deniedOutlets &&
      metadata.deniedOutlets.includes(targetOutletName)
    ) {
      return false;
    }
    if (metadata.allowedOutlets?.length > 0) {
      return metadata.allowedOutlets.includes(targetOutletName);
    }
    return true;
  }

  /**
   * Moves the entry identified by `sourceKey` to a new position in the
   * layout, applying the mutation to the relevant draft layer(s) and
   * recording the affected outlets so the toolbar's `isDirty`/Save and
   * `resetAll` paths pick the change up.
   *
   * Same-outlet moves are a single immutable rebuild via `moveEntry`.
   * Cross-outlet moves split into `removeEntry` from the source outlet and
   * `insertEntryAt` on the target. Both paths re-publish via
   * `_setLayoutLayer`, which preserves entry references where possible —
   * the dragged block keeps its arg edits across the move.
   *
   * Returns true on a successful structural change. Returns false (and
   * leaves layouts untouched) when the source/target can't be located, the
   * block isn't allowed in the target outlet, or the move would create a
   * self-nesting cycle (handled inside `moveEntry`).
   *
   * @param {{
   *   sourceKey: string,
   *   targetKey: string|null,
   *   position: "before"|"after"|"inside",
   *   targetOutletName: string,
   * }} args
   * @returns {boolean}
   */
  @action
  moveBlock({ sourceKey, targetKey, position, targetOutletName }) {
    const source = this._findEntryAndOutletSync(sourceKey);
    if (!source) {
      return false;
    }
    if (!this.canDropAt({ targetOutletName })) {
      return false;
    }
    if (source.outletName === targetOutletName) {
      return this._moveWithinOutlet(
        source.outletName,
        sourceKey,
        targetKey,
        position
      );
    }
    return this._moveAcrossOutlets({
      sourceOutletName: source.outletName,
      targetOutletName,
      sourceEntry: source.entry,
      sourceKey,
      targetKey,
      position,
    });
  }

  _moveWithinOutlet(outletName, sourceKey, targetKey, position) {
    const layout = this.readResolvedLayout(outletName);
    if (!layout) {
      return false;
    }
    const result = moveEntry(layout, sourceKey, targetKey, position);
    if (!result.changed) {
      return false;
    }
    this._publishStructuralChange(outletName, result.layout);
    return true;
  }

  _moveAcrossOutlets({
    sourceOutletName,
    targetOutletName,
    sourceKey,
    targetKey,
    position,
  }) {
    const sourceLayout = this.readResolvedLayout(sourceOutletName);
    const targetLayout = this.readResolvedLayout(targetOutletName);
    if (!sourceLayout || !targetLayout) {
      return false;
    }
    const removal = removeEntry(sourceLayout, sourceKey);
    if (!removal.changed || !removal.removed) {
      return false;
    }
    const insertion = insertEntryAt(
      targetLayout,
      targetKey,
      removal.removed,
      position
    );
    if (!insertion.changed) {
      return false;
    }
    // Publish both outlets in one go — the editor service holds both as
    // session-draft layers, so each `_setLayoutLayer` call only re-resolves
    // its own outlet's chain.
    this._publishStructuralChange(sourceOutletName, removal.layout);
    this._publishStructuralChange(targetOutletName, insertion.layout);
    return true;
  }

  /**
   * Re-publishes a draft layout layer with structural changes applied and
   * marks the outlet as edited so save/reset/isDirty all pick it up.
   * Centralised so the same bookkeeping fires for every structural mutation
   * (move now, insert/delete in later phases).
   */
  _publishStructuralChange(outletName, newLayout) {
    _setLayoutLayer(
      outletName,
      LAYOUT_LAYERS.SESSION_DRAFT,
      newLayout,
      getOwner(this)
    );
    this._editedOutlets.add(outletName);
    this._structurallyEditedOutlets.add(outletName);
    this.structuralVersion++;
  }

  /**
   * Synchronous variant of `_findEntryAndOutlet` — uses `record.layout`
   * (already-resolved) instead of awaiting `record.validatedLayout`. Drag
   * handlers fire after validation has long since completed, so the sync
   * lookup is safe and avoids forcing every call site to be async.
   *
   * @param {string} key
   * @returns {{entry: Object, outletName: string}|null}
   */
  _findEntryAndOutletSync(key) {
    const layoutMap = _getOutletLayouts();
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

  /** @param {string} key */
  _findEntryByKey(key) {
    return this._findEntryAndOutletSync(key)?.entry ?? null;
  }

  _metadataFor(entry) {
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
}
