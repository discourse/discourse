import Service, { service } from "@ember/service";
import type { BlockMetadata } from "discourse/blocks/types";
import type WireframeDragSessionService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-drag-session";
import type WireframeLayoutQueryService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-query";

/**
 * Decides whether a drag/insert is allowed into a target outlet — the
 * per-dragover authorization the drop targets consult.
 *
 * A pure-read peer service: it injects the drag-session signal (the in-flight
 * source block) and the read-only layout query layer (entry + block metadata
 * lookups). Only query methods (no mutators), so the orchestrator exposes the instance
 * directly through its `dropAuthority` facade.
 */
export default class WireframeDropAuthorityService extends Service {
  /** Identifies the block and source outlet of the current drag. */
  @service declare wireframeDragSession: WireframeDragSessionService;
  /** Resolves block entries and their registered outlet restrictions. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;

  /**
   * Whether dropping the currently-dragged block into `targetOutletName` is
   * allowed. Same-outlet moves (and an idle session) always pass; cross-outlet
   * moves consult the source block's outlet restrictions.
   *
   * @param target - The proposed destination.
   */
  canDropAt({
    targetOutletName,
  }: {
    /** Outlet receiving the dragged block. */
    targetOutletName: string;
  }): boolean {
    const sourceKey = this.wireframeDragSession.sourceKey;
    if (!sourceKey) {
      return true;
    }
    if (
      !targetOutletName ||
      targetOutletName === this.wireframeDragSession.sourceOutlet
    ) {
      return true;
    }
    const sourceEntry = this.wireframeLayoutQuery.findEntryByKey(sourceKey);
    if (!sourceEntry) {
      return false;
    }
    return this.#outletAllowed(
      this.wireframeLayoutQuery.metadataFor(sourceEntry),
      targetOutletName
    );
  }

  /**
   * Whether inserting a fresh `blockName` block into `targetOutletName` is
   * allowed by the block class's outlet restrictions. The insert path, with no
   * in-flight drag source to consult.
   *
   * @param target - The block and proposed destination.
   */
  canInsertBlockAt({
    blockName,
    targetOutletName,
  }: {
    /** Registered name of the block being inserted. */
    blockName: string;
    /** Outlet receiving the new block. */
    targetOutletName: string;
  }): boolean {
    if (!blockName || !targetOutletName) {
      return false;
    }
    return this.#outletAllowed(
      this.wireframeLayoutQuery.metadataForName(blockName),
      targetOutletName
    );
  }

  /**
   * Shared allow/deny check. Permissive when metadata is missing (an
   * unregistered block — the server-side validator catches a truly broken one
   * on save); `deniedOutlets` blocks; a non-empty `allowedOutlets` is a strict
   * allow-list.
   *
   * @param metadata - Outlet restrictions declared by the block.
   * @param targetOutletName - Outlet being considered.
   */
  #outletAllowed(
    metadata: BlockMetadata | null,
    targetOutletName: string
  ): boolean {
    if (!metadata) {
      return true;
    }
    if (metadata.deniedOutlets?.includes(targetOutletName)) {
      return false;
    }
    const allowedOutlets = metadata.allowedOutlets;
    if (allowedOutlets?.length) {
      return allowedOutlets.includes(targetOutletName);
    }
    return true;
  }
}
