// @ts-check
import { trackedObject } from "@ember/reactive/collections";

/**
 * Pure drag-session state for the block editor: which block (or palette entry)
 * is being dragged right now.
 *
 * A dependency-free leaf — the kernel owns it and drives it one-way; it never
 * reaches back into any service. The `begin*`/`clear` methods record state ONLY;
 * the kernel's `startDrag`/`startPaletteDrag`/`endDrag` wrap them with the side
 * effects (the `wireframe-dragging` body class, resetting the drag overlay).
 */
export default class DragSessionState {
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
}
