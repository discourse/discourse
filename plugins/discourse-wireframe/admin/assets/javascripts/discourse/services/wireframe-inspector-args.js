// @ts-check
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import discourseDebounce from "discourse/lib/debounce";
import { setPartOverride } from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";

// Idle delay after the last keystroke before a burst of inspector-arg edits is
// flushed into the layout as a single batch.
const FLUSH_DELAY_MS = 200;

/**
 * Owns the debounced inspector-arg edit pipeline: a burst of keystrokes on a
 * selected block's args is accumulated, then flushed as one batch into the
 * resolved entry's `args` (or, for a selected composite part, into the owning
 * composite's per-part override map). The block's reactive getters propagate
 * the change through Glimmer's autotracking — no layout swap, no inspector
 * remount.
 *
 * A peer service in the editor's acyclic dependency graph. It injects only the
 * services downstream of it — the mutation/undo engine (records the batch), the
 * read-only layout query layer (entry/outlet/part lookups), and the selection
 * concern (the flush targets the selected block). It never reaches back up into
 * the orchestrator that drives it; the orchestrator keeps a thin `updateSelectedArg` facade
 * so its consumers stay unchanged.
 *
 * It subscribes to the selection seam itself: a pending burst is flushed before
 * the selection moves off the block those keystrokes targeted (see the
 * constructor).
 */
export default class WireframeInspectorArgsService extends Service {
  @service wireframeMutationEngine;
  @service wireframeLayoutQuery;
  @service wireframeSelection;

  /**
   * Pending arg changes for the currently-selected block, accumulated across
   * a burst of keystrokes and flushed by `#flushPendingArgs` after a short
   * idle delay. Keys are arg names; values are the latest value typed.
   *
   * @type {Map<string, *>}
   */
  #pendingArgs = new Map();

  constructor() {
    super(...arguments);
    // Own our reaction to selection changes: flush anything still pending from
    // the previous selection so we don't apply those keystrokes to the new
    // block by accident. The flush reads the selected block key BEFORE the
    // selection mutates (beforeChange fires first), so it lands on the outgoing
    // block.
    //
    // Registered once at instantiation and permanent for the app lifetime (the
    // seam has no unregister). It fires on every selection change regardless of
    // editor active-state, which is safe: the guard no-ops when nothing is
    // pending. The composition root looks this service up at boot so the
    // subscription exists before the first selection change.
    this.wireframeSelection.registerBeforeChange(() => {
      if (this.#pendingArgs.size > 0) {
        this.#flushPendingArgs();
      }
    });
  }

  /**
   * Whether a debounced arg edit is still waiting to be flushed. A primitive
   * projection (not the pending map) so callers can gate on it without reaching
   * the mutable state.
   *
   * @returns {boolean}
   */
  get hasPending() {
    return this.#pendingArgs.size > 0;
  }

  /**
   * Discards any pending (un-flushed) arg edits without applying them. Called by
   * the orchestrator's `exit()` so a burst left mid-debounce can't bleed into a later
   * session — the session-draft layer is dropped on exit regardless.
   */
  clear() {
    this.#pendingArgs.clear();
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
    if (!this.wireframeSelection.selectedBlockKey) {
      return;
    }
    this.#pendingArgs.set(argName, value);
    discourseDebounce(this, this.#flushPendingArgs, FLUSH_DELAY_MS);
  }

  /**
   * Applies every pending arg change in one shot by mutating the resolved
   * entry's `args` directly. The block's reactive getters propagate the
   * change through Glimmer's autotracking — no layout swap, no DOM
   * tear-down, no inspector remount.
   *
   * Captures the pre-edit snapshot BEFORE applying the mutation so reset /
   * exit / undo have the original state to restore. Records the affected
   * outlet in `editedOutlets` so persistence knows what to POST on Save.
   *
   * @returns {Promise<boolean>} True if the flush touched an entry.
   */
  async #flushPendingArgs() {
    const key = this.wireframeSelection.selectedBlockKey;
    if (!key || this.#pendingArgs.size === 0) {
      return false;
    }
    const pending = [...this.#pendingArgs.entries()];
    this.#pendingArgs.clear();

    // A selected composite part has no persisted entry: its edits are written
    // to the owning composite's per-part override map (a structural commit),
    // not into a tracked entry's args.
    const partContext = this.wireframeLayoutQuery.resolvePartContext(key);
    if (partContext) {
      return this.#flushPendingPartArgs(partContext, pending);
    }

    const located = await this.wireframeLayoutQuery.findEntryAndOutlet(key);
    if (!located) {
      return false;
    }
    const { entry, outletName } = located;

    const prevMap = new Map();
    for (const [argName] of pending) {
      prevMap.set(argName, entry.args?.[argName]);
    }

    // The engine flags the outlet, captures the FULL pre-edit snapshot before
    // applying the mutation (so reset / exit have a complete rollback target),
    // writes the new values, and pushes a single `args` undo entry.
    this.wireframeMutationEngine.recordArgBatch({
      entry,
      outletName,
      prevMap,
      nextMap: new Map(pending),
    });

    return true;
  }

  /**
   * Commits a batch of pending arg edits for a selected composite part by
   * merging them into the owning composite entry's per-part override map. This
   * is a structural commit (the synthesis reads `entry.overrides` at render
   * time, and synthesized part args aren't tracked objects), so it routes
   * through `recordStructural` for undo/redo and re-publishes the draft layer.
   * Setting an arg to `null`/`undefined` removes it from the override (reverting
   * that arg to the part's code default).
   *
   * @param {{compositeKey: string, outletName: string, partPath: string}} partContext
   * @param {Array<[string, *]>} pending
   * @returns {boolean}
   */
  #flushPendingPartArgs({ compositeKey, outletName, partPath }, pending) {
    return this.wireframeMutationEngine.recordStructural([outletName], () => {
      const layout = this.wireframeLayoutQuery.readResolvedLayout(outletName);
      if (!layout) {
        return false;
      }
      const result = setPartOverride(
        layout,
        compositeKey,
        partPath,
        (current) => {
          const merged = { ...current };
          for (const [argName, value] of pending) {
            if (value == null) {
              delete merged[argName];
            } else {
              merged[argName] = value;
            }
          }
          return merged;
        }
      );
      if (!result.changed) {
        return false;
      }
      this.wireframeMutationEngine.publishStructuralChange(
        outletName,
        result.layout
      );
      return true;
    });
  }
}
