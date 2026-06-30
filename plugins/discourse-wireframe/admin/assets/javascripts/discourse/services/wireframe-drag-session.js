// @ts-check
import { action } from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import Service, { service } from "@ember/service";

/**
 * Drag-session state for the block editor: which block (or palette entry) is
 * being dragged right now, plus the drag lifecycle entry points the drag
 * sources call.
 *
 * The `begin*`/`clear` methods record state ONLY; the public
 * `startDrag`/`startPaletteDrag`/`endDrag` wrap them with the side effect of
 * resetting the drag overlay. The `wireframe-dragging` body class is a
 * declarative binding the editor chrome drives off `dragActive`, not a side
 * effect set here.
 */
export default class WireframeDragSessionService extends Service {
  @service wireframeDragOverlay;

  /**
   * Private drag state. `sourceKey`/`sourceOutlet` are read through the getters
   * below; `source` (the full `{type, data}` descriptor) is currently write-only
   * (no reader) — kept for parity and a possible future dragover consumer, which
   * must read it as a FROZEN projection, never the raw object (its `data` /
   * `defaultArgs` are mutable). Held in a `#`-private `trackedObject` so the
   * live, mutable values are unreachable from outside this class.
   *
   * @type {{ sourceKey: ?string, sourceOutlet: ?string, source: {type: string, data: Object}|null }}
   */
  #state = trackedObject({ sourceKey: null, sourceOutlet: null, source: null });

  /**
   * The key of the block being dragged, or `null` for a palette (new-block)
   * drag or when no drag is in progress.
   *
   * @returns {?string}
   */
  get sourceKey() {
    return this.#state.sourceKey;
  }

  /**
   * The outlet the dragged block came from, or `null`.
   *
   * @returns {?string}
   */
  get sourceOutlet() {
    return this.#state.sourceOutlet;
  }

  /**
   * Whether an existing block is being dragged. `false` during a palette drag
   * (those carry no source block) and when idle.
   *
   * @returns {boolean}
   */
  get isDragging() {
    return this.#state.sourceKey != null;
  }

  /**
   * Whether any drag is in progress — an existing-block move OR a palette
   * (new-block) drag. Unlike `isDragging`, this stays `true` through a palette
   * drag, so it's the signal the editor chrome binds the `wireframe-dragging`
   * body class to. Cleared by `clear()` on drop or cancel.
   *
   * @returns {boolean}
   */
  get dragActive() {
    return this.#state.source != null;
  }

  /**
   * Records the start of an existing-block drag.
   *
   * @param {{ blockKey: string, outletName: string }} payload
   */
  beginBlock({ blockKey, outletName }) {
    this.#state.sourceKey = blockKey;
    this.#state.sourceOutlet = outletName;
    this.#state.source = { type: "wf-block", data: { blockKey, outletName } };
  }

  /**
   * Records the start of a palette (new-block) drag. Leaves `sourceKey` null —
   * a palette drag isn't a move, so `isDragging` stays `false`.
   *
   * @param {{ blockName: string, defaultArgs: Object }} payload
   */
  beginPalette({ blockName, defaultArgs }) {
    this.#state.source = {
      type: "wf-palette-block",
      data: { blockName, defaultArgs },
    };
  }

  /**
   * Clears all drag state (drop or cancel).
   */
  clear() {
    this.#state.sourceKey = null;
    this.#state.sourceOutlet = null;
    this.#state.source = null;
  }

  /**
   * Begins an existing-block drag: resets any stale preview and records the
   * source. Recording the source flips `dragActive`, which drives the editor's
   * `wireframe-dragging` body class.
   *
   * @param {{ blockKey: string, outletName: string }} payload
   */
  @action
  startDrag({ blockKey, outletName }) {
    this.wireframeDragOverlay.clear();
    this.beginBlock({ blockKey, outletName });
  }

  /**
   * Begins a palette (new-block) drag. Mirrors `startDrag` with the
   * `wf-palette-block` type so dragover-time consumers pick the right label /
   * dispatch action.
   *
   * @param {{ blockName: string, defaultArgs: Object }} payload
   */
  @action
  startPaletteDrag({ blockName, defaultArgs }) {
    this.wireframeDragOverlay.clear();
    this.beginPalette({ blockName, defaultArgs });
  }

  /**
   * Resets per-drag state at the end of a drag (drop OR cancel). Wired as the
   * source modifier's `onDrop` consumer, deferred until after the drop handler
   * has consumed the overlay via `dispatch()`.
   */
  @action
  endDrag() {
    this.clear();
    this.wireframeDragOverlay.clear();
  }
}
