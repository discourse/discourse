// @ts-check
import Service from "@ember/service";

/**
 * @typedef {Object} DragPayload
 * @property {string} type - Discriminator string set by the source.
 * @property {*} data - Arbitrary payload the source attached to the drag.
 * @property {Element} element - The element that originated the drag.
 */

/**
 * Tracks the in-flight drag for the `dDragAndDropSource` /
 * `dDragAndDropTarget` modifier pair. Targets and observers can read
 * the source's payload synchronously during a drag — useful when the
 * native `DataTransfer` API hides values cross-origin (only types are
 * readable during `dragover`) and the consumer needs the payload
 * before the drop event lands.
 *
 * Lives as a service rather than a module slot so test setup
 * (`setupTest` / `setupRenderingTest`) gets a fresh instance per test,
 * and so modifier classes can inject it via `@service`.
 */
export default class DragAndDropService extends Service {
  /** @type {DragPayload|null} */
  currentDrag = null;

  /**
   * Stores the in-flight drag's payload. Called by `dDragAndDropSource`
   * from its `onDragStart` callback.
   *
   * @param {DragPayload} payload
   */
  setCurrentDrag(payload) {
    this.currentDrag = payload;
  }

  /**
   * Clears the in-flight drag. Called by `dDragAndDropSource` from its
   * `onDrop` callback — fires regardless of whether the drop landed on
   * a target or was cancelled.
   */
  clearCurrentDrag() {
    this.currentDrag = null;
  }

  /**
   * Does the in-flight drag's `type` match the supplied `accepts`
   * filter? Drop targets call this from their event handlers before
   * reacting.
   *
   * @param {string|string[]} accepts - Single type string or array.
   * @returns {boolean}
   */
  accepts(accepts) {
    if (!this.currentDrag || !accepts) {
      return false;
    }
    if (Array.isArray(accepts)) {
      return accepts.includes(this.currentDrag.type);
    }
    return this.currentDrag.type === accepts;
  }

  /**
   * @deprecated — use `accepts` instead. Kept here only as a guardrail
   *   for legacy callers we may have missed; will be removed once the
   *   migration is complete.
   * @param {string|string[]} accepts
   * @returns {boolean}
   */
  isAccepted(accepts) {
    return this.accepts(accepts);
  }
}
