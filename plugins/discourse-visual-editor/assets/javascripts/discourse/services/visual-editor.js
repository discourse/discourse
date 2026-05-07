// @ts-check
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import Service, { service } from "@ember/service";
import { _getOutletLayouts } from "discourse/blocks/block-outlet";
import discourseDebounce from "discourse/lib/debounce";
import { findEntry } from "../lib/mutate-layout";
import { inferSchemaFromValues } from "../lib/schema-to-fields";

const FLUSH_DELAY_MS = 200;

/**
 * Phase 1 + 2 editor service. Holds the editor's session state and mediates
 * the in-memory mutation pipeline.
 *
 * Reactivity contract: every `@tracked` field on this service is read by the
 * panels and the canvas chrome. Mutating one re-renders the relevant pieces
 * via Glimmer's tracking system without manual notification.
 *
 * Phase 2's mutation pipeline takes advantage of `entry.args` being a
 * `trackedObject` (wrapped in `block-outlet.gjs`'s `assignStableKeys`) and
 * `createBlockArgsWithReactiveGetters` defining reactive getters that read
 * straight from it. Setting `entry.args[name] = value` therefore propagates
 * to the rendered block via Glimmer's autotracking — no layout swap, no
 * component re-curry, no DOM tear-down. The block whose arg changed
 * re-renders the affected getter site; everything else stays put.
 *
 * Persistence and drag-drop remain out of scope until later phases.
 */
export default class VisualEditorService extends Service {
  @service blocks;
  @service currentUser;
  @service siteSettings;

  @tracked isActive = false;
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
   * before the first mutation. "Reset" walks this map and writes those
   * snapshots back into `entry.args`.
   *
   * @type {Map<Object, Map<string, *>>}
   */
  _initialSnapshots = new Map();

  /**
   * Pending arg changes for the currently-selected block, accumulated across
   * a burst of keystrokes and flushed by `_flushPendingArgs` after a short
   * idle delay. Keys are arg names; values are the latest value typed.
   *
   * @type {Map<string, *>}
   */
  _pendingArgs = new Map();

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
  enter() {
    if (!this.canEdit) {
      return;
    }
    this.isActive = true;
    document.body.classList.add("visual-editor-active");
  }

  @action
  exit() {
    this.isActive = false;
    this.selectedBlockKey = null;
    this.selectedBlockData = null;
    this._undoStack.length = 0;
    this._redoStack.length = 0;
    this._initialSnapshots.clear();
    this._pendingArgs.clear();
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
    return this._initialSnapshots.size > 0;
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
    // current values.
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
      // `record.layout` is the raw layout array exposed alongside the
      // validatedLayout promise — synchronously accessible from the moment
      // the layout is registered. We don't await `validatedLayout` here so
      // the click → select path stays fully synchronous.
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
   * Phase 2 limitation: walks layouts via `_getOutletLayouts()`, which only
   * returns the live map in DEBUG builds. In production the mutation is a
   * no-op until Phase 3 lands the public layout-resolution API.
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
   * Applies every pending arg change in one shot by mutating `entry.args`
   * directly. The block's reactive getters propagate the change through
   * Glimmer's autotracking — no layout swap, no DOM tear-down.
   *
   * Captures both the pre-batch and post-batch arg values for undo / redo,
   * so undoing rolls back the entire burst rather than replaying keystrokes
   * one at a time.
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

    const entry = await this._findEntry(key);
    if (!entry) {
      return false;
    }

    const prev = new Map();
    const next = new Map();
    for (const [argName] of pending) {
      prev.set(argName, entry.args?.[argName]);
    }
    for (const [argName, value] of pending) {
      next.set(argName, value);
      entry.args[argName] = value;
    }

    this._captureInitialSnapshot(entry, prev);
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
   * Restores every touched entry back to its initial (pre-edit) args and
   * clears history. Used by the toolbar's "Reset" affordance.
   *
   * @returns {Promise<boolean>}
   */
  @action
  async resetAll() {
    if (!this.isDirty) {
      return false;
    }
    for (const [entry, snapshot] of this._initialSnapshots) {
      this._writeArgs(entry, snapshot);
    }
    this._undoStack.length = 0;
    this._redoStack.length = 0;
    this._initialSnapshots.clear();
    return true;
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
   * later edits we apply on top.
   */
  _captureInitialSnapshot(entry, prev) {
    if (this._initialSnapshots.has(entry)) {
      return;
    }
    // The `prev` map may not include keys the entry already had but which
    // we never edited; the snapshot needs ALL of them so reset is a true
    // round-trip. Take a shallow clone of the full args object.
    const fullSnapshot = new Map();
    for (const [k, v] of Object.entries(entry.args ?? {})) {
      fullSnapshot.set(k, v);
    }
    // Layer in the just-captured `prev` for any keys we're now editing
    // that weren't already in the snapshot (defensive — shouldn't happen
    // since we read `entry.args[k]` to populate `prev`).
    for (const [k, v] of prev) {
      if (!fullSnapshot.has(k)) {
        fullSnapshot.set(k, v);
      }
    }
    this._initialSnapshots.set(entry, fullSnapshot);
  }

  /**
   * Walks every registered outlet's layout looking for the entry whose
   * composite key matches. Returns the live (mutable) layout entry so the
   * caller can mutate `entry.args` in place.
   */
  async _findEntry(key) {
    const layoutMap = _getOutletLayouts();
    for (const [, entryRecord] of layoutMap) {
      let layout;
      try {
        layout = await entryRecord.validatedLayout;
      } catch {
        continue;
      }
      const found = findEntry(layout, key);
      if (found) {
        return found;
      }
    }
    return null;
  }
}
