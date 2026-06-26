// @ts-check
import { action } from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import Service, { service } from "@ember/service";
import { cloneEntryForPaste, insertEntryAt } from "../lib/mutate-layout";

/**
 * Owns the copy / cut / paste clipboard for whole-block subtrees. The stash
 * holds a deep clone of an entry with its stable keys stripped, so a paste
 * mints fresh keys and subsequent canvas edits never leak into the stash.
 *
 * A peer service in the editor's acyclic dependency graph: it injects the
 * mutation/undo engine (paste rides the structural chokepoint), the read-only
 * layout query layer (entry/outlet lookups), and the selection concern (copy /
 * cut / paste all act on the selected block). It never reaches back up into the
 * kernel; the kernel keeps thin facades so its consumers stay unchanged.
 *
 * It is purely command-driven — `copySelected` / `cutSelected` /
 * `pasteFromClipboard` are invoked imperatively (the keyboard shortcuts) — so,
 * unlike the reveal / inline-edit / arg-edit services, it does NOT subscribe to
 * the selection seam and needs no boot-time instantiation.
 *
 * Cut is intentionally only HALF here: `cutSelected` stashes the entry, but the
 * removal is a structural operation the kernel still owns (`removeBlock` carries
 * the outlet-root guard, the entry-removal helper, and the selection-clear). The
 * kernel orchestrates the two halves; this service is the clipboard alone.
 */
export default class WireframeClipboardService extends Service {
  @service wireframeEditEngine;
  @service wireframeLayoutQuery;
  @service wireframeSelection;

  /**
   * The stashed payload: `entry` is a stable-key-stripped clone of the copied /
   * cut block, `mode` records how it got there (`"copy"` / `"cut"`). Held in a
   * `#`-private tracked object so the public getters stay reactive without
   * exposing the mutable state. `entry` / `mode` are `null` when empty.
   *
   * @type {{entry: Object|null, mode: "copy"|"cut"|null}}
   */
  #state = trackedObject({ entry: null, mode: null });

  /**
   * How the current stash was captured (`"copy"` / `"cut"`), or `null` when the
   * clipboard is empty. A read-only projection — the two modes behave
   * identically at paste time; the distinction is kept for affordances that want
   * to differentiate a copy from a cut.
   *
   * @returns {"copy"|"cut"|null}
   */
  get clipboardMode() {
    return this.#state.mode;
  }

  /**
   * Indicates whether the clipboard currently holds anything that
   * `pasteFromClipboard` could insert.
   *
   * @returns {boolean}
   */
  get hasClipboardEntry() {
    return this.#state.entry != null;
  }

  /**
   * Captures the currently-selected block onto the clipboard for later
   * paste. The captured entry is a fresh deep clone with stable keys
   * stripped, so subsequent mutations on the canvas don't leak into the
   * clipboard payload.
   *
   * @returns {boolean} true on success, false when no block is selected
   */
  @action
  copySelected() {
    return this.#stash("copy");
  }

  /**
   * Captures the currently-selected block onto the clipboard with mode `"cut"`.
   * This ONLY stashes — the caller (the kernel) performs the structural removal,
   * because removal carries kernel-owned nuance (outlet-root guard,
   * selection-clear). Stashes unconditionally once the entry is located, so a
   * cut whose removal later no-ops (e.g. an outlet root) still mirrors the
   * original behaviour.
   *
   * @returns {boolean} true on success, false when no block is selected
   */
  @action
  cutSelected() {
    return this.#stash("cut");
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
   * @returns {boolean}
   */
  @action
  pasteFromClipboard() {
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
    return this.wireframeEditEngine.recordStructural(
      [located.outletName],
      () => {
        const layout = this.wireframeLayoutQuery.readResolvedLayout(
          located.outletName
        );
        if (!layout) {
          return false;
        }
        const insertion = insertEntryAt(
          layout,
          targetKey,
          cloneEntryForPaste(this.#state.entry),
          "after"
        );
        if (!insertion.changed) {
          return false;
        }
        this.wireframeEditEngine.publishStructuralChange(
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
   * ones. No outlet-root guard — root-ness is the kernel `removeBlock`'s
   * concern, not the stash's.
   *
   * @param {"copy"|"cut"} mode
   * @returns {boolean} true when an entry was stashed.
   */
  #stash(mode) {
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
