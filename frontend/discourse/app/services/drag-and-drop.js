// @ts-check
import Service from "@ember/service";

/**
 * @typedef {Object} DragPayload
 * @property {string} kind - Discriminator string set by the source.
 * @property {*} data - Arbitrary payload the source attached to the drag.
 * @property {Element} sourceElement - The element that originated the drag.
 */

/**
 * Tracks the in-flight drag for the `drag-and-drop-source` /
 * `drag-and-drop-target` modifier pair. Drop targets need to read the
 * source's payload during `dragover` to decide whether to accept and how
 * to highlight, but `event.dataTransfer.getData(...)` returns an empty
 * string during dragover for cross-origin security — only types are
 * readable. We stash the full payload here on `dragstart` and read it
 * back during `dragover` / `drop`.
 *
 * Lives as a service rather than a module slot so test setup
 * (`setupTest`/`setupRenderingTest`) gets a fresh instance per test, and
 * because modifier classes already inject other services via `@service`.
 */
export default class DragAndDropService extends Service {
  /** @type {DragPayload|null} */
  currentDrag = null;

  /**
   * Stores the in-flight drag's payload. Called by `drag-and-drop-source`
   * from its `dragstart` handler.
   *
   * @param {DragPayload} payload
   */
  setCurrentDrag(payload) {
    this.currentDrag = payload;
  }

  /**
   * Clears the in-flight drag. Called by `drag-and-drop-source` from its
   * `dragend` handler — fires regardless of whether the drop landed on a
   * target or was cancelled.
   */
  clearCurrentDrag() {
    this.currentDrag = null;
  }

  /**
   * Convenience: does the in-flight drag's `kind` match the supplied
   * `accepts` filter? Drop targets call this from their event handlers
   * before reacting.
   *
   * @param {string|string[]} accepts - Single kind string or array.
   * @returns {boolean}
   */
  isAccepted(accepts) {
    if (!this.currentDrag || !accepts) {
      return false;
    }
    if (Array.isArray(accepts)) {
      return accepts.includes(this.currentDrag.kind);
    }
    return this.currentDrag.kind === accepts;
  }
}
