import Service, { service } from "@ember/service";
import type BlocksService from "discourse/services/blocks";
import { serializeLayoutForSave } from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";
import type WireframeLayoutQueryService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-query";
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
  /** Resolves the published layout used as the comparison baseline. */
  @service declare blocks: BlocksService;
  /** Resolves the edited layout shown in the publish preview. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;

  /**
   * The structural change summary for an outlet — how its edited layout differs
   * from the live (published or default) baseline. Compares the underlying source
   * (resolved with `ignoreSessionDraft`) against the in-session draft on top.
   *
   * @param outletName - Outlet whose draft should be compared with its baseline.
   * @returns Counts describing the structural changes.
   */
  outletChangeSummary(outletName: string): ReturnType<typeof diffLayouts> {
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
   * @param outletName - Outlet whose draft should be serialized.
   * @returns Pretty-printed save JSON for the outlet.
   */
  outletLayoutJson(outletName: string): string {
    const layout = serializeLayoutForSave(
      this.wireframeLayoutQuery.readResolvedLayout(outletName) ?? []
    );
    return JSON.stringify(layout, null, 2);
  }
}
