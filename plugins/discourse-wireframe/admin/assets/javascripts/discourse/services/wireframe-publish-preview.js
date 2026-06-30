// @ts-check
import Service, { service } from "@ember/service";
import { serializeLayoutForSave } from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";
import { diffLayouts } from "../lib/outlet-change-summary";

/**
 * Derives the publish review drawer's per-outlet preview: the structural change
 * summary (edited layout vs the live baseline) and the pretty-printed save JSON
 * of the edited layout. A read-only peer service — it owns no state, deriving
 * everything from the live resolved layouts on each read. Injects the core
 * block layer (the pre-edit baseline) and the read-only layout query layer (the
 * in-session edited layout).
 */
export default class WireframePublishPreviewService extends Service {
  @service blocks;
  @service wireframeLayoutQuery;

  /**
   * The structural change summary for an outlet — how its edited layout differs
   * from the live (published or default) baseline. Compares the underlying source
   * (resolved with `ignoreSessionDraft`) against the in-session draft on top.
   *
   * @param {string} outletName
   * @returns {{added: number, removed: number, moved: number, edited: number, reliable: boolean}}
   */
  outletChangeSummary(outletName) {
    const before = this.blocks.resolvedLayout(outletName, {
      ignoreSessionDraft: true,
    });
    const after = this.wireframeLayoutQuery.readResolvedLayout(outletName);
    return diffLayouts(before, after);
  }

  /**
   * The pretty-printed JSON of an outlet's edited layout, for the raw-layout view.
   * Uses the canonical save serializer so it matches what a publish would persist.
   *
   * @param {string} outletName
   * @returns {string}
   */
  outletLayoutJson(outletName) {
    const layout = serializeLayoutForSave(
      this.wireframeLayoutQuery.readResolvedLayout(outletName) ?? []
    );
    return JSON.stringify(layout, null, 2);
  }
}
