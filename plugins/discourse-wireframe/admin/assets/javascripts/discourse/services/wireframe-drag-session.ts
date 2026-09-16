import { action } from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import Service, { service } from "@ember/service";
import type WireframeDragOverlayService from "./wireframe-drag-overlay";

/** Identity of an existing block drag. */
export interface BlockDragPayload {
  /** Composite key of the dragged block. */
  blockKey: string;
  /** Outlet containing the dragged block. */
  outletName: string;
}

/** Identity and defaults of a new palette block drag. */
export interface PaletteDragPayload {
  /** Registered block name. */
  blockName: string;
  /** Stable palette choice represented by the drag source. */
  paletteId?: string;
  /** Label shown by drop targets while dragging. */
  displayName?: string;
  /** Arguments applied when the block is inserted. */
  defaultArgs?: Record<string, unknown>;
}

type DragSource =
  | {
      /** Identifies a drag of an existing block. */
      type: "wf-block";
      /** Existing block being dragged. */
      data: BlockDragPayload;
    }
  | {
      /** Identifies a drag from the block palette. */
      type: "wf-palette-block";
      /** Palette block being inserted. */
      data: PaletteDragPayload;
    };

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
  /** Owns the visual drop preview that is reset around each drag. */
  @service declare wireframeDragOverlay: WireframeDragOverlayService;

  /**
   * Private drag state. `sourceKey`/`sourceOutlet` are read through the getters
   * below; `source` (the full `{type, data}` descriptor) is currently write-only
   * (no reader) — kept for parity and a possible future dragover consumer, which
   * must read it as a FROZEN projection, never the raw object (its `data` /
   * `defaultArgs` are mutable). Held in a `#`-private `trackedObject` so the
   * live, mutable values are unreachable from outside this class.
   */
  #state: {
    /** Full drag descriptor, or `null` while idle. */
    source: DragSource | null;
    /** Composite key for an existing-block drag. */
    sourceKey: string | null;
    /** Source outlet for an existing-block drag. */
    sourceOutlet: string | null;
  } = trackedObject({
    sourceKey: null,
    sourceOutlet: null,
    source: null,
  });

  /**
   * The key of the block being dragged, or `null` for a palette (new-block)
   * drag or when no drag is in progress.
   */
  get sourceKey(): string | null {
    return this.#state.sourceKey;
  }

  /**
   * The outlet the dragged block came from, or `null`.
   */
  get sourceOutlet(): string | null {
    return this.#state.sourceOutlet;
  }

  /**
   * Whether an existing block is being dragged. `false` during a palette drag
   * (those carry no source block) and when idle.
   */
  get isDragging(): boolean {
    return this.#state.sourceKey != null;
  }

  /**
   * Whether any drag is in progress — an existing-block move OR a palette
   * (new-block) drag. Unlike `isDragging`, this stays `true` through a palette
   * drag, so it's the signal the editor chrome binds the `wireframe-dragging`
   * body class to. Cleared by `clear()` on drop or cancel.
   */
  get dragActive(): boolean {
    return this.#state.source != null;
  }

  /**
   * Records the start of an existing-block drag.
   *
   * @param payload - Identity of the existing block being dragged.
   */
  beginBlock({ blockKey, outletName }: BlockDragPayload): void {
    this.#state.sourceKey = blockKey;
    this.#state.sourceOutlet = outletName;
    this.#state.source = { type: "wf-block", data: { blockKey, outletName } };
  }

  /**
   * Records the start of a palette (new-block) drag. Leaves `sourceKey` null —
   * a palette drag isn't a move, so `isDragging` stays `false`.
   *
   * @param payload - Registration and initial arguments of the new block.
   */
  beginPalette({
    blockName,
    paletteId,
    displayName,
    defaultArgs,
  }: PaletteDragPayload): void {
    this.#state.source = {
      type: "wf-palette-block",
      data: { blockName, paletteId, displayName, defaultArgs },
    };
  }

  /**
   * Clears all drag state (drop or cancel).
   */
  clear(): void {
    this.#state.sourceKey = null;
    this.#state.sourceOutlet = null;
    this.#state.source = null;
  }

  /**
   * Begins an existing-block drag: resets any stale preview and records the
   * source. Recording the source flips `dragActive`, which drives the editor's
   * `wireframe-dragging` body class.
   *
   * @param payload - Identity of the existing block being dragged.
   */
  @action
  startDrag({ blockKey, outletName }: BlockDragPayload): void {
    this.wireframeDragOverlay.clear();
    this.beginBlock({ blockKey, outletName });
  }

  /**
   * Begins a palette (new-block) drag. Mirrors `startDrag` with the
   * `wf-palette-block` type so dragover-time consumers pick the right label /
   * dispatch action.
   *
   * @param payload - Registration and initial arguments of the new block.
   */
  @action
  startPaletteDrag({ blockName, defaultArgs }: PaletteDragPayload): void {
    this.wireframeDragOverlay.clear();
    this.beginPalette({ blockName, defaultArgs });
  }

  /**
   * Resets per-drag state at the end of a drag (drop OR cancel). Wired as the
   * source modifier's `onDrop` consumer, deferred until after the drop handler
   * has consumed the overlay via `dispatch()`.
   */
  @action
  endDrag(): void {
    this.clear();
    this.wireframeDragOverlay.clear();
  }
}
