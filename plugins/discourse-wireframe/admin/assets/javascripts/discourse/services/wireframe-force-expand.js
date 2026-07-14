// @ts-check
import { trackedSet } from "@ember/reactive/collections";
import Service from "@ember/service";

/**
 * Owns the per-session "force-expand" set — the block keys the author has
 * explicitly expanded for editing (a collapsed `wf:layout` opened in place so
 * its children can be edited / dropped into). Pure session UI state: nothing is
 * persisted, and the set is cleared when the editing session ends.
 *
 * A dependency-free peer service; consumers reach it through the editor session
 * service's thin facades, so they never poke the underlying set directly.
 */
export default class WireframeForceExpandService extends Service {
  #keys = trackedSet();

  /**
   * Whether `blockKey` is currently force-expanded.
   *
   * @param {string} blockKey
   * @returns {boolean}
   */
  isForceExpanded(blockKey) {
    return blockKey ? this.#keys.has(blockKey) : false;
  }

  /**
   * Flips the force-expand state for a single `wf:layout` block. The change is
   * reactive — the chrome wrapper's class list re-renders immediately to add or
   * remove `--force-expanded`, and `GridOverlay` sees an `isCollapsed` flip on
   * its next dragover.
   *
   * @param {string} blockKey
   */
  toggleForceExpand(blockKey) {
    if (!blockKey) {
      return;
    }
    if (this.#keys.has(blockKey)) {
      this.#keys.delete(blockKey);
    } else {
      this.#keys.add(blockKey);
    }
  }

  /**
   * Clears every force-expanded key. Called when the editing session ends so
   * force-expand state never leaks across sessions.
   */
  reset() {
    this.#keys.clear();
  }
}
