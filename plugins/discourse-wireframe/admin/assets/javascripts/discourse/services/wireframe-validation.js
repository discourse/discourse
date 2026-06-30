// @ts-check
import Service, { service } from "@ember/service";
import { _getResolvedLayouts } from "discourse/blocks/block-outlet";

/**
 * Surfaces the editor's validation warnings — the per-entry `__failureReason`
 * stamps the permissive validator leaves behind — as a flat list the chrome and
 * the publish drawer banner render. A read-only peer service: it owns no state,
 * deriving everything from the live resolved layouts on each read.
 *
 * Depends only on the layout signal (to re-evaluate after a structural
 * republish); consumers reach it through the orchestrator's facades.
 */
export default class WireframeValidationService extends Service {
  @service wireframeLayoutSignal;

  /**
   * Validation warnings across every outlet the editor is currently
   * drafting. Walks each outlet's resolved layout and harvests the
   * per-entry `__failureReason` stamps the permissive validator leaves
   * behind (paired 1:1 with the layer-level warnings — see
   * `validation/layout.js`'s `markEntrySoftFailure` + `context.warnings`).
   *
   * Reading the stamps rather than the layer record's frozen
   * `validationWarnings` array is what lets the inspector banner clear
   * the moment the author fixes a failing arg: in-place arg writes go
   * through `writeArgs`, which deletes the entry's stamps but doesn't
   * touch the layer array. The two surfaces (per-block ghost chrome,
   * outlet-wide banner) now agree on the live state.
   *
   * Reactivity: reads the layout signal so structural republishes
   * re-evaluate; entry stamp reads (on the trackedObject-wrapped entry)
   * open their own deps so arg-edit stamp clears propagate too.
   * Validation itself is async (`validatedLayout` is a lazy Promise
   * resolved after `BlockOutlet` first reads it); on the very first
   * render after a publish, stamps may not yet be populated and this
   * getter returns an empty list until the next tick.
   *
   * @returns {Array<{outletName: string, message: string}>}
   */
  get validationWarnings() {
    // The layout signal covers republishes (validation re-runs against
    // the freshly-published layer). In-place stamp changes propagate via
    // the per-entry `trackedObject` wrap — each `entry.__failureReason`
    // read below opens a per-key dep that fires when `revalidateEntryStamps`
    // rewrites or deletes `entry.__failureReason` on an arg edit.
    void this.wireframeLayoutSignal.version;
    const layoutMap = _getResolvedLayouts();
    const warnings = [];
    for (const [outletName, record] of layoutMap) {
      if (!record?.layout) {
        continue;
      }
      this.#collectStampedWarnings(record.layout, outletName, warnings);
    }
    return warnings;
  }

  /** @returns {boolean} */
  get hasValidationWarnings() {
    return this.validationWarnings.length > 0;
  }

  /**
   * Recursively walks `entries` and pushes one `{outletName, message}`
   * warning for every entry carrying a `__failureReason` stamp. Reads
   * `__failureReason` rather than the truthy stamp pair (`__failureType`
   * is also set) because the message is what the UI surfaces.
   *
   * @param {Array<Object>} entries
   * @param {string} outletName
   * @param {Array<{outletName: string, message: string}>} warnings
   */
  #collectStampedWarnings(entries, outletName, warnings) {
    for (const entry of entries) {
      if (entry?.__failureReason) {
        warnings.push({ outletName, message: entry.__failureReason });
      }
      if (entry?.children?.length) {
        this.#collectStampedWarnings(entry.children, outletName, warnings);
      }
    }
  }
}
