import { getOwner } from "@ember/owner";
import {
  trackedArray,
  trackedMap,
  trackedSet,
} from "@ember/reactive/collections";
import Service, { service } from "@ember/service";
import {
  _clearLayoutLayer,
  _setLayoutLayer,
  LAYOUT_LAYERS,
} from "discourse/blocks/block-outlet";
import type { LayoutEntry } from "discourse/blocks/types";
import {
  cloneLayoutForDraft,
  normalizeImplicitChildren,
  revalidateEntryStamps,
  sameValue,
  serializeLayoutForSave,
  wrapAsOutletRoot,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";
import WireframeLayoutQueryService, {
  OUTLET_STATE,
} from "./wireframe-layout-query";
import type WireframeLayoutSignalService from "./wireframe-layout-signal";
import type WireframeSelectionService from "./wireframe-selection";

/** Values needed to record one inline argument edit. */
type ArgEdit = {
  /** Name of the edited argument. */
  argName: string;
  /** Resolved entry that owns the argument. */
  entry: LayoutEntry;
  /** Value written by the edit. */
  nextValue: unknown;
  /** Outlet containing the entry. */
  outletName: string;
  /** Value captured when the edit session opened. */
  prevValue: unknown;
};

type ArgBatch = {
  /** Resolved entry receiving the argument changes. */
  entry: LayoutEntry;
  /** Values written by the batch. */
  nextMap: Map<string, unknown>;
  /** Outlet containing the resolved entry. */
  outletName: string;
  /** Values captured before the batch. */
  prevMap: Map<string, unknown>;
};

/** One undoable batch of argument changes on a resolved entry. */
export type ArgUndoBatch = {
  /** Identifies an argument-edit undo entry. */
  kind: "args";
  /** Resolved entry whose arguments changed. */
  entry: LayoutEntry;
  /** Argument values restored by undo. */
  prev: Map<string, unknown>;
  /** Argument values restored by redo. */
  next: Map<string, unknown>;
};

type StructuralChange = {
  /** Outlet affected by the structural mutation. */
  outletName: string;
  /** Layout restored by undo, or absence before a first draft. */
  prevLayout: LayoutEntry[] | null;
  /** Layout restored by redo, or absence after removal. */
  nextLayout: LayoutEntry[] | null;
};

type StructuralUndoBatch = {
  /** Identifies a structural undo entry. */
  kind: "structural";
  /** Per-outlet layout snapshots participating in the mutation. */
  changes: StructuralChange[];
  /** Selection restored by undo. */
  prevSelection: string | null;
  /** Selection restored by redo. */
  nextSelection: string | null;
};

type UndoBatch = ArgUndoBatch | StructuralUndoBatch;

/**
 * Owns the editor's mutation + undo + dirty-tracking chokepoint — the single
 * place every in-memory edit (arg writes, structural mutations, undo/redo)
 * funnels through, plus the bookkeeping that tells the toolbar "there are
 * unsaved changes" and persistence "these outlets need saving".
 *
 * A peer service in the editor's acyclic dependency graph: it injects only the
 * services that sit downstream of it — the layout-signal beacon (`bump`), the
 * read-only layout query layer (entry/outlet lookups), and the selection
 * concern (`selectedBlockKey` + `restoreSelection`, so structural undo/redo can
 * follow the selection across layout snapshots). It never reaches back up into
 * the orchestrator that drives it; the orchestrator keeps thin facade delegators so its
 * many `recordStructural` / `publishStructuralChange` / `setArg` callers stay
 * unchanged.
 *
 * No raw mutable state is exposed: the dirty sets, the snapshot map, and the
 * undo/redo stacks are all private. Consumers read through intent-revealing
 * query methods (`isOutletEdited`, `isDirty`, `canUndo`, …) and frozen
 * projections (`editedOutletNames`, `draftedOutletNames`), and write through
 * named operations (`markOutletArgEdited`, `recordStructural`, …).
 */
export default class WireframeMutationEngineService extends Service {
  /** Invalidates consumers after layout mutations. */
  @service declare wireframeLayoutSignal: WireframeLayoutSignalService;

  /** Resolves layout entries, outlets, and block metadata. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;

  /** Reads and restores the active block selection. */
  @service declare wireframeSelection: WireframeSelectionService;

  /**
   * Undo / redo stacks for in-memory edits. Entries are discriminated by
   * `kind`:
   *
   * - `{kind: "args", entry, prev, next}` — one batch of arg mutations on a
   *   specific entry. Undo writes `prev` back into `entry.args`, redo flips
   *   to `next`.
   * - `{kind: "structural", changes, prevSelection, nextSelection}` — a
   *   structural mutation (insert / remove / move / duplicate / paste /
   *   conditions / raw-json edit). `changes` is an array of
   *   `{outletName, prevLayout, nextLayout}` pairs. Undo re-publishes the
   *   `prev` layouts; redo re-publishes `next`. Selection is restored
   *   alongside because structural changes can delete or relocate the
   *   selected block.
   *
   */
  #undoStack = trackedArray<UndoBatch>();

  /** Mutations available to reapply after an undo. */
  #redoStack = trackedArray<UndoBatch>();

  /**
   * For each entry we've ever mutated, the `entry.args` snapshot taken
   * before the first mutation. Reset / exit walk this map and write those
   * snapshots back into `entry.args`.
   *
   * Stored as a `trackedMap` so reads of `.size` (used by `isDirty`) open
   * a tracked dependency on the collection — that's what keeps the toolbar's
   * Save / Reset buttons reactive to the very first edit.
   *
   */
  #initialSnapshots = trackedMap<LayoutEntry, Map<string, unknown>>();

  /**
   * Outlets where this editor session has materialised a `session-draft`
   * layer. Tracked here (rather than re-derived from the block-outlet
   * record) so `exit` clears exactly what the editor published without
   * touching drafts produced elsewhere.
   *
   */
  #draftedOutlets = new Set<string>();

  /**
   * Names of every outlet whose draft layer has at least one in-memory
   * mutation. Persistence iterates this set on Save to know which outlet
   * layouts to POST. Cleared per-outlet after a successful save, and
   * wholesale on `exit` / `resetAll`. Plain Set on purpose — untracked; the
   * dirty signal rides on `#initialSnapshots` / `#structurallyEditedOutlets`.
   *
   */
  #editedOutlets = new Set<string>();

  /**
   * Pristine clones of every drafted outlet's layout, captured at `enter()`
   * time. Used by `resetAll()` to roll structural mutations (drag/drop,
   * insert, delete) back to the page's pre-edit state.
   *
   * Stored as a separate clone from the draft itself so subsequent edits
   * (which mutate the draft in place) never bleed into the snapshot.
   *
   */
  #originalLayouts = new Map<string, LayoutEntry[]>();

  /**
   * Outlets whose draft has at least one structural mutation (block moved,
   * inserted, deleted). A `trackedSet` so the toolbar's `isDirty` getter
   * reactively responds to the first move — equivalent role to
   * `#initialSnapshots` for arg edits.
   *
   */
  #structurallyEditedOutlets = trackedSet<string>();

  /** @returns Whether any in-memory edit can be undone. */
  get canUndo(): boolean {
    return this.#undoStack.length > 0;
  }

  /** @returns Whether an undone edit can be redone. */
  get canRedo(): boolean {
    return this.#redoStack.length > 0;
  }

  /**
   * The number of entries on the undo stack. A read-only scalar projection (not
   * the stack itself) so consumers can tell whether a recording pushed a new
   * entry without reaching the mutable stack.
   *
   * @returns Number of undoable mutations.
   */
  get undoDepth(): number {
    return this.#undoStack.length;
  }

  /**
   * The number of entries on the redo stack — the redo-side counterpart to
   * `undoDepth`.
   *
   * @returns Number of redoable mutations.
   */
  get redoDepth(): number {
    return this.#redoStack.length;
  }

  /**
   * Whether there's any unsaved edit — arg or structural — across all outlets.
   *
   * @returns Whether any outlet has an unsaved mutation.
   */
  get isDirty(): boolean {
    return (
      this.#initialSnapshots.size > 0 ||
      this.#structurallyEditedOutlets.size > 0
    );
  }

  /**
   * The number of outlets flagged as edited. A plain read of the untracked
   * `#editedOutlets` set — it does NOT open a reactive dependency; use `isDirty`
   * when reactivity is needed.
   *
   * @returns Number of outlets flagged as edited.
   */
  get editedOutletsSize(): number {
    return this.#editedOutlets.size;
  }

  /**
   * Whether an outlet has any unsaved edit — structural or arg-level.
   * `#editedOutlets` is a superset of `#structurallyEditedOutlets`, so this one
   * predicate covers both. Walks the arg snapshots to catch outlets edited only
   * at the arg level.
   *
   * @param outletName - Outlet whose edit state should be queried.
   * @returns Whether the outlet has an unsaved mutation.
   */
  isOutletEdited(outletName: string): boolean {
    if (this.#structurallyEditedOutlets.has(outletName)) {
      return true;
    }
    if (this.#initialSnapshots.size === 0) {
      return false;
    }
    for (const entry of this.#initialSnapshots.keys()) {
      if (this.wireframeLayoutQuery.outletForEntry(entry) === outletName) {
        return true;
      }
    }
    return false;
  }

  /**
   * The set of outlet names with any unsaved edit — structural or arg-level —
   * computed from the edit bookkeeping, as a frozen array so callers can
   * iterate while the underlying bookkeeping mutates and can't mutate it back.
   *
   * @returns Frozen snapshot of edited outlet names.
   */
  editedOutletNames(): readonly string[] {
    return Object.freeze([...this.#editedOutletNames()]);
  }

  /**
   * Whether the editor has materialised a `session-draft` layer for `outletName`.
   *
   * @param outletName - Outlet whose draft state should be queried.
   * @returns Whether the editor materialized a draft for the outlet.
   */
  isOutletDrafted(outletName: string): boolean {
    return this.#draftedOutlets.has(outletName);
  }

  /**
   * A frozen array of every outlet the editor has drafted. Consumers read this
   * instead of the live set so they can't mutate it.
   *
   * @returns Frozen snapshot of drafted outlet names.
   */
  draftedOutletNames(): readonly string[] {
    return Object.freeze([...this.#draftedOutlets]);
  }

  /**
   * Flags an outlet as having an arg-level edit (a typed value, an image, an
   * icon, a URL). Does NOT flag it as structurally edited.
   *
   * @param outletName - Outlet to mark as argument-edited.
   */
  markOutletArgEdited(outletName: string): void {
    this.#editedOutlets.add(outletName);
  }

  /**
   * Flags an outlet as structurally edited (block inserted / moved / deleted /
   * re-parented). Implies arg-edited too, so both sets are flagged.
   *
   * @param outletName - Outlet to mark as structurally edited.
   */
  markOutletStructurallyEdited(outletName: string): void {
    this.#editedOutlets.add(outletName);
    this.#structurallyEditedOutlets.add(outletName);
  }

  /**
   * Drops an outlet from the edited set after it has been published — the
   * live-layout service's post-publish cleanup. Leaves the layout on the canvas.
   *
   * @param outletName - Outlet whose published edit flag should be cleared.
   */
  markOutletPublished(outletName: string): void {
    this.#editedOutlets.delete(outletName);
  }

  /**
   * Records that the editor materialised a `session-draft` layer for an outlet.
   *
   * @param outletName - Outlet whose draft layer was materialized.
   */
  markOutletDrafted(outletName: string): void {
    this.#draftedOutlets.add(outletName);
  }

  /**
   * Ensures a session-draft layer exists for `outletName`. Used by mutation
   * actions that target outlets the user is populating from scratch — those
   * outlets have no published layout, but the empty-outlet drop zone lets
   * authors add the first block. We mint an empty draft here so the subsequent
   * `publishStructuralChange` has somewhere to land, mark the outlet drafted,
   * and capture its baseline as the rollback target.
   *
   * Idempotent: bails when a draft already exists.
   *
   * @param outletName - Outlet that must have an editable draft.
   * @returns Existing or freshly minted draft layout.
   */
  ensureDraft(outletName: string): LayoutEntry[] {
    const existing = this.wireframeLayoutQuery.readResolvedLayout(outletName);
    if (existing) {
      return existing;
    }
    // A LOCKED outlet is read-only — never mint a draft for it. This is a
    // defensive backstop; the chrome already gates writes on `isOutletEditable`.
    if (
      this.wireframeLayoutQuery.outletState(outletName) === OUTLET_STATE.LOCKED
    ) {
      return existing ?? [];
    }
    // Seed the outlet with an empty root `layout` block so it's an implicit
    // layout from the first drop, matching `#materializeAllDrafts`.
    const emptyDraft = wrapAsOutletRoot([]);
    _setLayoutLayer(
      outletName,
      LAYOUT_LAYERS.SESSION_DRAFT,
      emptyDraft,
      getOwner(this),
      { permissive: true }
    );
    this.markOutletDrafted(outletName);
    this.wireframeLayoutQuery.recordOutletRoot(outletName);
    this.captureBaseline(
      outletName,
      cloneLayoutForDraft(
        this.wireframeLayoutQuery.readResolvedLayout(outletName) ?? []
      )
    );
    return (
      this.wireframeLayoutQuery.readResolvedLayout(outletName) ?? emptyDraft
    );
  }

  /**
   * Forgets that the editor drafted an outlet (e.g. on a reset-to-default).
   *
   * @param outletName - Outlet to remove from the drafted set.
   */
  markOutletUndrafted(outletName: string): void {
    this.#draftedOutlets.delete(outletName);
  }

  /**
   * Clears one outlet's dirty bookkeeping after it has been published — drops
   * its arg snapshots and edited flags WITHOUT rolling the layout back (the
   * published draft stays on the canvas). Unlike a discard, nothing reverts;
   * this just reconciles "no unsaved changes" for that outlet. Leaves the
   * persisted-draft baseline (owned by the orchestrator) to the caller.
   *
   * @param outletName - Published outlet whose edit bookkeeping should clear.
   */
  clearOutletEditState(outletName: string): void {
    for (const [entry] of this.#initialSnapshots) {
      if (this.wireframeLayoutQuery.outletForEntry(entry) === outletName) {
        this.#initialSnapshots.delete(entry);
      }
    }
    this.#structurallyEditedOutlets.delete(outletName);
    this.#editedOutlets.delete(outletName);
  }

  /**
   * Captures the pristine pre-edit clone for an outlet — the rollback target for
   * `resetAll`. Caller passes a fresh clone (the engine stores it as-is).
   *
   * @param outletName - Outlet whose pristine baseline is being captured.
   * @param layoutClone - Independent clone used for rollback.
   */
  captureBaseline(outletName: string, layoutClone: LayoutEntry[]): void {
    this.#originalLayouts.set(outletName, layoutClone);
  }

  /**
   * Drops every trace of an outlet from the engine's bookkeeping — its baseline,
   * arg snapshots, and edit flags — without rolling the layout back. Used by a
   * reset-to-default, which re-seeds a fresh draft afterwards.
   *
   * @param outletName - Outlet to remove from all engine bookkeeping.
   */
  dropOutlet(outletName: string): void {
    this.#draftedOutlets.delete(outletName);
    this.#originalLayouts.delete(outletName);
    for (const [entry] of this.#initialSnapshots) {
      if (this.wireframeLayoutQuery.outletForEntry(entry) === outletName) {
        this.#initialSnapshots.delete(entry);
      }
    }
    this.#structurallyEditedOutlets.delete(outletName);
    this.#editedOutlets.delete(outletName);
  }

  /**
   * Writes initial snapshots back into their entries, then clears every piece of
   * session edit state, and returns the outlet names that had drafts so the
   * orchestrator can clear their `session-draft` layers.
   *
   * The write-before-clear ordering matters: for test paths that bypass `enter()`
   * and mutate code-default entries directly, writing the snapshots back restores
   * them so test isolation holds; only then do we drop the snapshots.
   *
   * @returns Drafted outlet names captured before clearing.
   */
  flushSnapshotsAndReset(): string[] {
    for (const [entry, snapshot] of this.#initialSnapshots) {
      this.writeArgs(entry, snapshot);
    }
    const drafted = [...this.#draftedOutlets];
    this.#draftedOutlets.clear();
    this.#undoStack.length = 0;
    this.#redoStack.length = 0;
    this.#initialSnapshots.clear();
    this.#editedOutlets.clear();
    this.#originalLayouts.clear();
    this.#structurallyEditedOutlets.clear();
    return drafted;
  }

  /**
   * Clears both undo/redo stacks wholesale. Used after a full publish (the draft
   * entries the stacks reference no longer exist) and after a global reset.
   */
  clearStacks(): void {
    this.#undoStack.length = 0;
    this.#redoStack.length = 0;
  }

  /**
   * Pushes a pre-built undo batch (used by the two-phase in-session text edit,
   * which records its net change at `stop()` rather than per keystroke).
   *
   * @param batch - Completed argument-edit batch to append to undo history.
   */
  pushUndoEntry(batch: ArgUndoBatch): void {
    this.#undoStack.push(batch);
  }

  /** Empties the redo stack — any new edit invalidates redo history. */
  clearRedoStack(): void {
    this.#redoStack.length = 0;
  }

  /**
   * Removes an outlet's own entries from the undo/redo stacks — the per-outlet
   * counterpart to the global clear in a discard-all. A structural batch is
   * dropped only when EVERY change targets this outlet (a cross-outlet batch is
   * left intact); an arg batch is dropped when its entry belongs to this outlet.
   *
   * @param outletName - Outlet whose exclusively-owned history should clear.
   */
  dropUndoEntriesForOutlet(outletName: string): void {
    const referencesOnly = (batch: UndoBatch): boolean =>
      batch.kind === "structural"
        ? batch.changes.every((change) => change.outletName === outletName)
        : this.wireframeLayoutQuery.outletForEntry(batch.entry) === outletName;
    for (const stack of [this.#undoStack, this.#redoStack]) {
      for (let i = stack.length - 1; i >= 0; i--) {
        if (referencesOnly(stack[i])) {
          stack.splice(i, 1);
        }
      }
    }
  }

  /**
   * Reverts the most recent mutation. For `args` batches, writes the
   * captured `prev` values back into `entry.args`. For `structural`
   * batches, re-publishes the captured `prevLayout` on each affected
   * outlet and restores the pre-mutation selection.
   *
   * @returns Whether a mutation was undone.
   */
  async undo(): Promise<boolean> {
    if (!this.canUndo) {
      return false;
    }
    const batch = this.#undoStack.pop();
    if (!batch) {
      return false;
    }
    if (batch.kind === "structural") {
      this.#applyStructuralChanges(batch.changes, "prev");
      this.wireframeSelection.restoreSelection(batch.prevSelection);
      batch.changes.forEach((change: StructuralChange) =>
        this.#reconcileOutletEdited(change.outletName)
      );
    } else {
      this.writeArgs(batch.entry, batch.prev);
      this.#reconcileOutletEdited(
        this.wireframeLayoutQuery.outletForEntry(batch.entry)
      );
    }
    this.#redoStack.push(batch);
    return true;
  }

  /**
   * Re-applies the most recently undone mutation. Mirror image of `undo()`.
   *
   * @returns Whether a mutation was redone.
   */
  async redo(): Promise<boolean> {
    if (!this.canRedo) {
      return false;
    }
    const batch = this.#redoStack.pop();
    if (!batch) {
      return false;
    }
    if (batch.kind === "structural") {
      this.#applyStructuralChanges(batch.changes, "next");
      this.wireframeSelection.restoreSelection(batch.nextSelection);
      batch.changes.forEach((change: StructuralChange) =>
        this.#reconcileOutletEdited(change.outletName)
      );
    } else {
      this.writeArgs(batch.entry, batch.next);
      this.#reconcileOutletEdited(
        this.wireframeLayoutQuery.outletForEntry(batch.entry)
      );
    }
    this.#undoStack.push(batch);
    return true;
  }

  /**
   * Wraps a structural mutation so that it pushes an undo entry capturing
   * the pre/post layouts for every outlet it touches, plus the
   * pre/post selection. The caller passes the list of outlets that
   * `mutateFn` may write to; cross-outlet moves pass both source and
   * target so undo restores them in lockstep.
   *
   * If `mutateFn` returns a falsy value (i.e. the mutation no-op'd), no
   * undo entry is recorded and the falsy result propagates to the caller.
   *
   * @typeParam Result - Mutation result propagated to the caller.
   * @param outletNames - Outlets the mutation may update.
   * @param mutateFn - Mutation callback executed inside the undo boundary.
   * @returns The callback result.
   */
  recordStructural<Result>(
    outletNames: string[],
    mutateFn: () => Result
  ): Result {
    const prevLayouts = new Map<string, LayoutEntry[] | null>();
    for (const name of outletNames) {
      prevLayouts.set(name, this.#snapshotLayout(name));
    }
    const prevSelection = this.wireframeSelection.selectedBlockKey;
    const result = mutateFn();
    if (!result) {
      return result;
    }
    const changes: StructuralChange[] = [];
    for (const [name, prevLayout] of prevLayouts) {
      changes.push({
        outletName: name,
        prevLayout,
        nextLayout: this.#snapshotLayout(name),
      });
    }
    this.#undoStack.push({
      kind: "structural",
      changes,
      prevSelection,
      nextSelection: this.wireframeSelection.selectedBlockKey,
    });
    this.#redoStack.length = 0;
    // A structural edit that lands the outlet back on its pristine layout (e.g.
    // adding a block then removing it) must clear the edit bookkeeping, so the
    // "editing" state and the save/publish verbs reflect reality. The mutators
    // only ever flag an outlet as edited; this is the symmetric un-flag, mirroring
    // what undo/redo already do. The undo entry above is kept intact, so the edit
    // stays reversible even once the outlet reads as pristine.
    for (const { outletName: name } of changes) {
      this.#reconcileOutletEdited(name);
    }
    return result;
  }

  /**
   * Re-publishes a draft layout layer with structural changes applied and
   * marks the outlet as edited so save/reset/isDirty all pick it up.
   * Centralised so the same bookkeeping fires for every structural
   * mutation.
   *
   * @param outletName - Outlet whose draft layer should be republished.
   * @param newLayout - Structurally updated layout.
   */
  publishStructuralChange(outletName: string, newLayout: LayoutEntry[]): void {
    // Enforce every implicit-child-kind container's invariant at the one point
    // all structural mutations funnel through: a container declaring a single
    // `childBlocks` kind (e.g. tabs forcing `layout` panels) gets any
    // non-conforming child wrapped here, so insert / move / paste / drop /
    // duplicate all keep the invariant without per-path handling. A no-op for
    // layouts with no such container (returns the same reference).
    newLayout = normalizeImplicitChildren(newLayout, (ref) =>
      this.wireframeLayoutQuery.lookupBlockMetadata(ref)
    );
    _setLayoutLayer(
      outletName,
      LAYOUT_LAYERS.SESSION_DRAFT,
      newLayout,
      getOwner(this),
      // Permissive matches the initial draft publish — see the comment on
      // the orchestrator's draft materialisation. Without this, dragging the only
      // child out of a container produces an "EMPTY_CONTAINER" validation
      // failure which would crash the page.
      { permissive: true }
    );
    this.#editedOutlets.add(outletName);
    this.#structurallyEditedOutlets.add(outletName);
    this.wireframeLayoutSignal.bump();
  }

  /**
   * Writes a single arg value into the entry identified by `blockKey`,
   * immediately (not keystroke-debounced) and through the same write-path as
   * inspector edits so undo / redo / persistence stay consistent. The entry is
   * resolved synchronously so the canvas re-renders before the next paint.
   *
   * General-purpose: the image affordances (`setImageArg`, `uploadImageForArg`)
   * and the repeatable-array control route through here. Because the write is
   * immediate, a consumer that derives the next value from the current
   * `entry.args` (e.g. add-then-remove on an array) always reads a fresh value
   * rather than a stale pre-flush one.
   *
   * @param blockKey - Composite key of the entry to update.
   * @param argName - Name of the argument to update.
   * @param value - Replacement argument value.
   */
  setArg(blockKey: string, argName: string, value: unknown): void {
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(blockKey);
    if (!located?.entry) {
      return;
    }
    const { entry, outletName } = located;
    this.#editedOutlets.add(outletName);

    const prev = new Map([[argName, entry.args?.[argName]]]);
    this.captureInitialSnapshot(entry, prev);

    const next = new Map([[argName, value]]);
    this.writeArgs(entry, next);

    this.#undoStack.push({ kind: "args", entry, prev, next });
    this.#redoStack.length = 0;
  }

  /**
   * Commits one batch of arg edits on a resolved entry: flags the outlet,
   * captures the first-write snapshot, writes the values, and pushes a single
   * `args` undo entry (clearing redo). The shared tail the keystroke-flush calls
   * once it has resolved the entry and built the prev/next maps.
   *
   * @param batch - Resolved entry, outlet, and before/after argument maps.
   */
  recordArgBatch({ entry, outletName, prevMap, nextMap }: ArgBatch): void {
    this.#editedOutlets.add(outletName);
    this.captureInitialSnapshot(entry, prevMap);
    this.writeArgs(entry, nextMap);
    this.#undoStack.push({
      kind: "args",
      entry,
      prev: prevMap,
      next: nextMap,
    });
    this.#redoStack.length = 0;
  }

  /**
   * Single-key arg edit wrapper (the icon / link inline editors). Flags the
   * outlet, captures the first-write snapshot, and writes the value — then
   * pushes an undo entry only when the value actually changed, so re-selecting
   * the value already set doesn't pollute the undo stack.
   *
   * @param edit - Resolved entry, outlet, argument, and before/after values.
   */
  recordArgEdit({
    entry,
    outletName,
    argName,
    prevValue,
    nextValue,
  }: ArgEdit): void {
    this.#editedOutlets.add(outletName);
    const prevMap = new Map([[argName, prevValue]]);
    this.captureInitialSnapshot(entry, prevMap);
    this.writeArgs(entry, new Map([[argName, nextValue]]));

    if (!sameValue(prevValue, nextValue)) {
      this.#undoStack.push({
        kind: "args",
        entry,
        prev: prevMap,
        next: new Map([[argName, nextValue]]),
      });
      this.#redoStack.length = 0;
    }
  }

  /**
   * Writes a `Map<argName, value>` of arg values into `entry.args`. Used by
   * the keystroke flush, undo, redo, and reset. Each assignment goes through
   * the `trackedObject` proxy so reactive readers re-evaluate.
   *
   * `null` and `undefined` are treated as "no value" and delete the key
   * instead of writing it. `""` / `0` / `false` are written as-is — they're
   * valid scalar values for string / number / boolean args.
   *
   * Then re-runs arg + constraint validation for the entry against its
   * new args and refreshes its soft-failure stamps (`revalidateEntryStamps`).
   * The layer-wide validation pass only re-runs on republish, so without
   * this the outline / inspector would keep showing a stale error after the
   * author fixes the value — or, conversely, drop a still-valid error the
   * moment any edit lands. Re-validating per write keeps the displayed
   * errors honest between republishes.
   *
   * @param entry - Resolved entry whose args should be updated.
   * @param args - Argument names and replacement values.
   */
  writeArgs(entry: LayoutEntry, args: Map<string, unknown>): void {
    if (!entry?.args) {
      return;
    }
    for (const [argName, value] of args) {
      if (value == null) {
        delete entry.args[argName];
      } else {
        entry.args[argName] = value;
      }
    }
    revalidateEntryStamps(entry, { owner: getOwner(this) });
  }

  /**
   * Captures an entry's pre-edit args the FIRST time it's about to be
   * mutated, so `resetAll()` has a stable target regardless of how many
   * later edits we apply on top. Caller MUST invoke this BEFORE applying
   * the mutation — otherwise the snapshot captures the post-edit state.
   *
   * @param entry - Entry about to receive its first mutation.
   * @param prev - Values observed immediately before that mutation.
   */
  captureInitialSnapshot(entry: LayoutEntry, prev: Map<string, unknown>): void {
    if (this.#initialSnapshots.has(entry)) {
      return;
    }
    // Snapshot the entire pre-edit args object so reset is a true
    // round-trip even when later batches edit different keys. The `prev`
    // map is layered in for any keys it carries that aren't already in
    // the snapshot — defensive, since `prev` is built from `entry.args`
    // reads in the same critical section.
    const fullSnapshot = new Map<string, unknown>();
    for (const [k, v] of Object.entries(entry.args ?? {})) {
      fullSnapshot.set(k, v);
    }
    for (const [k, v] of prev) {
      if (!fullSnapshot.has(k)) {
        fullSnapshot.set(k, v);
      }
    }
    this.#initialSnapshots.set(entry, fullSnapshot);
  }

  /**
   * In-memory rollback of every touched outlet to its pristine pre-edit state,
   * then clears the undo/redo history. Each outlet is reverted by
   * `rollbackOutletInMemory` (which handles both structural and arg edits); no
   * server field is touched. Returns false when there's nothing to reset.
   *
   * @returns Whether any dirty state was reset.
   */
  async resetAll(): Promise<boolean> {
    if (!this.isDirty) {
      return false;
    }
    for (const outletName of this.#editedOutletNames()) {
      this.rollbackOutletInMemory(outletName);
    }
    this.#undoStack.length = 0;
    this.#redoStack.length = 0;
    return true;
  }

  /**
   * Rolls a single outlet's session draft back to the pristine layout captured
   * at `enter()` (or at draft hydration) and clears its edit bookkeeping. The
   * baseline clone is re-published wholesale, so both structural and arg edits
   * revert; for the rare case with no captured clone, the per-entry arg snapshots
   * are written back instead. In-memory only — no server call.
   *
   * @param outletName - Outlet whose in-memory mutations should be rolled back.
   */
  rollbackOutletInMemory(outletName: string): void {
    const original = this.#originalLayouts.get(outletName);
    if (original) {
      // Clone again so the snapshot stays pristine across repeated resets.
      // Permissive matches the original draft publish.
      _setLayoutLayer(
        outletName,
        LAYOUT_LAYERS.SESSION_DRAFT,
        cloneLayoutForDraft(original),
        getOwner(this),
        { permissive: true }
      );
      // The snapshot preserves the root layout's `__stableKey`, so the recorded
      // root key normally stays valid — re-record defensively regardless.
      this.wireframeLayoutQuery.recordOutletRoot(outletName);
    }
    for (const [entry, snapshot] of this.#initialSnapshots) {
      if (this.wireframeLayoutQuery.outletForEntry(entry) !== outletName) {
        continue;
      }
      // With a re-published clone the fresh draft already carries pristine args,
      // so just drop the (now-stale) snapshot; without one, write it back.
      if (!original) {
        this.writeArgs(entry, snapshot);
      }
      this.#initialSnapshots.delete(entry);
    }
    this.#structurallyEditedOutlets.delete(outletName);
    this.#editedOutlets.delete(outletName);
  }

  /**
   * The set of outlet names with any unsaved edit — structural or arg-level —
   * computed from the edit bookkeeping. Snapshotted (a new Set) so callers can
   * iterate while mutating the underlying bookkeeping.
   *
   * @returns Snapshot of edited outlet names.
   */
  #editedOutletNames(): Set<string> {
    const names = new Set<string>(this.#structurallyEditedOutlets);
    for (const entry of this.#initialSnapshots.keys()) {
      const outletName = this.wireframeLayoutQuery.outletForEntry(entry);
      if (outletName) {
        names.add(outletName);
      }
    }
    return names;
  }

  /**
   * Captures a deep clone of `outletName`'s currently-resolved layout, or
   * `null` when the outlet has no published layout yet (the latter happens
   * when the editor is about to mint a fresh draft for an empty outlet).
   * Used as the before/after snapshot in structural undo entries.
   *
   * @param outletName - Outlet whose resolved layout should be cloned.
   * @returns Deep layout snapshot, or `null` when no layout resolves.
   */
  #snapshotLayout(outletName: string): LayoutEntry[] | null {
    const layout = this.wireframeLayoutQuery.readResolvedLayout(outletName);
    return layout ? cloneLayoutForDraft(layout) : null;
  }

  /**
   * Recomputes whether an outlet still counts as edited by comparing its current
   * session draft to the pristine layout captured at `enter()`. When they match —
   * e.g. after undoing every edit back to the starting point — the outlet's edit
   * bookkeeping is cleared so the "Editing" badge and the save/publish verbs
   * reflect reality. A real (non-pristine) edit is left marked; the mutators
   * already flag those, so this only ever clears.
   *
   * @param outletName - Outlet whose current layout should be compared.
   */
  #reconcileOutletEdited(outletName: string | null | undefined): void {
    if (!outletName) {
      return;
    }
    const original = this.#originalLayouts.get(outletName);
    const current = this.wireframeLayoutQuery.readResolvedLayout(outletName);
    const isPristine =
      JSON.stringify(serializeLayoutForSave(current ?? [])) ===
      JSON.stringify(serializeLayoutForSave(original ?? []));
    if (!isPristine) {
      return;
    }
    this.#structurallyEditedOutlets.delete(outletName);
    this.#editedOutlets.delete(outletName);
    for (const entry of [...this.#initialSnapshots.keys()]) {
      if (this.wireframeLayoutQuery.outletForEntry(entry) === outletName) {
        this.#initialSnapshots.delete(entry);
      }
    }
  }

  /**
   * Republishes a list of `{outletName, prevLayout, nextLayout}` changes in
   * the given direction. When the target snapshot is `null` (i.e. the
   * outlet had no draft before the mutation), the SESSION_DRAFT layer is
   * cleared instead of re-published, restoring the resolved layout chain
   * to whatever lower layers (theme / code-default) carry.
   *
   * @param changes - Per-outlet before and after layout snapshots.
   * @param direction - Snapshot side to publish.
   */
  #applyStructuralChanges(
    changes: StructuralChange[],
    direction: "prev" | "next"
  ): void {
    for (const change of changes) {
      const layout =
        direction === "prev" ? change.prevLayout : change.nextLayout;
      if (layout == null) {
        _clearLayoutLayer(change.outletName, LAYOUT_LAYERS.SESSION_DRAFT);
        // The outlet returns to its un-drafted state — drop bookkeeping
        // so isDirty / save no longer flag it.
        this.#draftedOutlets.delete(change.outletName);
        this.#structurallyEditedOutlets.delete(change.outletName);
        this.#editedOutlets.delete(change.outletName);
        continue;
      }
      _setLayoutLayer(
        change.outletName,
        LAYOUT_LAYERS.SESSION_DRAFT,
        cloneLayoutForDraft(layout),
        getOwner(this),
        { permissive: true }
      );
      this.#draftedOutlets.add(change.outletName);
      this.#editedOutlets.add(change.outletName);
      this.#structurallyEditedOutlets.add(change.outletName);
    }
    this.wireframeLayoutSignal.bump();
  }
}
