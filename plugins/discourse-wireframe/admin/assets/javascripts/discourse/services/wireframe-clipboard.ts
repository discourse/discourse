import { action } from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import Service, { service } from "@ember/service";
import type { LayoutEntry } from "discourse/blocks/types";
import {
  cloneEntryForPaste,
  insertEntryAt,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";
import type WireframeBlockMutationsService from "./wireframe-block-mutations";
import type WireframeLayoutQueryService from "./wireframe-layout-query";
import type WireframeMutationEngineService from "./wireframe-mutation-engine";
import type WireframeSelectionService from "./wireframe-selection";

/** How the current clipboard entry was captured. */
export type ClipboardMode = "copy" | "cut";

/**
 * Owns the copy / cut / paste clipboard for whole-block subtrees. The stash
 * holds a deep clone of an entry with its stable keys stripped, so a paste
 * mints fresh keys and subsequent canvas edits never leak into the stash.
 *
 * A peer service in the editor's acyclic dependency graph: it injects the
 * mutation/undo engine (paste rides the structural chokepoint), the read-only
 * layout query layer (entry/outlet lookups), and the selection concern (copy /
 * cut / paste all act on the selected block).
 *
 * It is purely command-driven — `copySelected` / `cutSelected` /
 * `pasteFromClipboard` are invoked imperatively (the keyboard shortcuts) — so,
 * unlike the reveal / in-place-text / inspector-args services, it does NOT subscribe to
 * the selection seam and needs no boot-time instantiation.
 *
 * Cut is a composition: this service stashes the entry (mode `"cut"`) and then
 * removes it via `wireframeBlockMutations.removeBlock`, which carries the
 * structural nuance (outlet-root guard, entry-removal helper, selection-clear).
 */
export default class WireframeClipboardService extends Service {
  /** Removes a selected block after a successful cut. */
  @service declare wireframeBlockMutations: WireframeBlockMutationsService;
  /** Records paste operations inside the structural undo boundary. */
  @service declare wireframeMutationEngine: WireframeMutationEngineService;
  /** Resolves selected entries and their containing outlets. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;
  /** Supplies the block targeted by clipboard commands. */
  @service declare wireframeSelection: WireframeSelectionService;

  /**
   * The stashed payload: `entry` is a stable-key-stripped clone of the copied /
   * cut block, `mode` records how it got there (`"copy"` / `"cut"`). Held in a
   * `#`-private tracked object so the public getters stay reactive without
   * exposing the mutable state. `entry` / `mode` are `null` when empty.
   */
  #state: {
    /** Stable-key-free entry subtree ready to be cloned for insertion. */
    entry: LayoutEntry | null;
    /** Operation that populated the clipboard. */
    mode: ClipboardMode | null;
  } = trackedObject({ entry: null, mode: null });

  /**
   * How the current stash was captured (`"copy"` / `"cut"`), or `null` when the
   * clipboard is empty. A read-only projection — the two modes behave
   * identically at paste time; the distinction is kept for affordances that want
   * to differentiate a copy from a cut.
   *
   * @returns Operation that populated the clipboard, or `null` when empty.
   */
  get clipboardMode(): ClipboardMode | null {
    return this.#state.mode;
  }

  /**
   * Indicates whether the clipboard currently holds anything that
   * `pasteFromClipboard` could insert.
   *
   */
  get hasClipboardEntry(): boolean {
    return this.#state.entry != null;
  }

  /**
   * Captures the currently-selected block onto the clipboard for later
   * paste. The captured entry is a fresh deep clone with stable keys
   * stripped, so subsequent mutations on the canvas don't leak into the
   * clipboard payload.
   *
   * @returns `true` when an entry was copied.
   */
  @action
  copySelected(): boolean {
    return this.#stash("copy");
  }

  /**
   * Captures the currently-selected block onto the clipboard with mode `"cut"`
   * and removes it from the canvas. The key is captured before stashing (the
   * stash doesn't change selection); if the stash fails (nothing selected / not
   * locatable) the removal is skipped.
   *
   * @returns `true` when an entry was stashed and removed.
   */
  @action
  cutSelected(): boolean {
    const key = this.wireframeSelection.selectedBlockKey;
    if (!key) {
      return false;
    }
    return this.#stash("cut") && this.wireframeBlockMutations.removeBlock(key);
  }

  /**
   * Inserts a fresh clone of the clipboard entry adjacent to the current
   * selection (after it, in the selected block's outlet). Each paste
   * re-clones the clipboard payload, so multiple `Cmd+V` taps insert
   * independent subtrees rather than aliasing the same node.
   *
   * Requires a selection. Returns false when there's nothing on the
   * clipboard, no block is currently selected, or the insert otherwise
   * no-ops (e.g. the selected block isn't locatable in the live layout).
   *
   * @returns `true` when a cloned entry was inserted.
   */
  @action
  pasteFromClipboard(): boolean {
    if (!this.#state.entry) {
      return false;
    }
    const targetKey = this.wireframeSelection.selectedBlockKey;
    if (!targetKey) {
      return false;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(targetKey);
    if (!located) {
      return false;
    }
    return this.wireframeMutationEngine.recordStructural(
      [located.outletName],
      () => {
        const layout = this.wireframeLayoutQuery.readResolvedLayout(
          located.outletName
        );
        if (!layout) {
          return false;
        }
        const clipboardEntry = this.#state.entry;
        if (!clipboardEntry) {
          return false;
        }
        const insertion = insertEntryAt(
          layout,
          targetKey,
          cloneEntryForPaste(clipboardEntry),
          "after"
        );
        if (!insertion.changed) {
          return false;
        }
        this.wireframeMutationEngine.publishStructuralChange(
          located.outletName,
          insertion.layout
        );
        return true;
      }
    );
  }

  /**
   * Clones the currently-selected entry into the stash with the given mode.
   * Stable keys are stripped by `cloneEntryForPaste` so a paste mints fresh
   * ones. No outlet-root guard — root-ness is block-mutations' `removeBlock`'s
   * concern, not the stash's.
   *
   * @param mode - Operation used to populate the clipboard.
   * @returns `true` when an entry was stashed.
   */
  #stash(mode: ClipboardMode): boolean {
    const key = this.wireframeSelection.selectedBlockKey;
    if (!key) {
      return false;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return false;
    }
    this.#state.entry = cloneEntryForPaste(located.entry);
    this.#state.mode = mode;
    return true;
  }
}
