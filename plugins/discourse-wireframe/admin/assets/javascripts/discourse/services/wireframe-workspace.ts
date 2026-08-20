import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import Service, { service } from "@ember/service";
import {
  registerBlockArgRenderer,
  resetBlockArgRenderer,
} from "discourse/blocks";
import loadInlineRichEditor from "discourse/lib/load-inline-rich-editor";
import type BlocksService from "discourse/services/blocks";
import ScaffoldedRichTextRenderer from "../components/scaffolded-rich-text-renderer";
import type WireframeBlockRevealService from "./wireframe-block-reveal";
import type WireframeDragOverlayService from "./wireframe-drag-overlay";
import type WireframeDragSessionService from "./wireframe-drag-session";
import type WireframeEditModeService from "./wireframe-edit-mode";
import type WireframeForceExpandService from "./wireframe-force-expand";
import type WireframeImageUploadService from "./wireframe-image-upload";
import type WireframeInspectorArgsService from "./wireframe-inspector-args";
import type WireframePublishTargetService from "./wireframe-publish-target";
import type WireframeSelectionService from "./wireframe-selection";
import type WireframeStagingService from "./wireframe-staging";

/**
 * The editor orchestrator. Opens and closes an editing session and sequences the
 * cross-concern setup/teardown — it owns no editing state of its own.
 *
 * `enter()` is an ordered, atomic transaction: mark the session active, bind the
 * target theme, light up the editor chrome (body class), swap in the
 * edit-aware rich-text renderer, and hand off to the staging service to seed the
 * editable draft layer. `exit()` reverses it, telling each peer concern to reset.
 * The ordering matters (renderer swap before the drafts are seeded; draft
 * teardown before the selection is cleared), which is why this stays a single
 * orchestrator rather than pub/sub choreography.
 *
 * Every per-concern state and command lives in a peer service this drives
 * one-way (it injects them; none inject it). The staging service owns the draft
 * layer and the publish/save/discard workflow; the session service owns the
 * is-open/can-edit signal everything else reads.
 */
export default class WireframeWorkspaceService extends Service {
  /** Core block registry and thumbnail preloader. */
  @service declare blocks: BlocksService;
  /** Clears inspector argument edits when a workspace closes. */
  @service declare wireframeInspectorArgs: WireframeInspectorArgsService;
  /** Resets reveal and flash state around workspace teardown. */
  @service declare wireframeBlockReveal: WireframeBlockRevealService;
  /** Owns the current visual drop preview. */
  @service declare wireframeDragOverlay: WireframeDragOverlayService;
  /** Owns the current drag source. */
  @service declare wireframeDragSession: WireframeDragSessionService;
  /** Owns layout blocks temporarily expanded for editing. */
  @service declare wireframeForceExpand: WireframeForceExpandService;
  /** Clears pending image uploads around workspace transitions. */
  @service declare wireframeImageUpload: WireframeImageUploadService;
  /** Owns the currently selected block. */
  @service declare wireframeSelection: WireframeSelectionService;
  /** Controls whether the editor session is active and allowed. */
  @service declare wireframeEditMode: WireframeEditModeService;
  /** Seeds and tears down editable layout drafts. */
  @service declare wireframeStaging: WireframeStagingService;
  /** Tracks the theme that receives published changes. */
  @service declare wireframePublishTarget: WireframePublishTargetService;

  /** Resets pending reveal work when Ember destroys the workspace service. */
  willDestroy(): void {
    super.willDestroy();
    // Defensive: a session torn down without an explicit exit (e.g. the owner
    // being destroyed) should still drop any pending reveal/flash timer.
    this.wireframeBlockReveal.reset();
  }

  /**
   * Opens an editing session for the selected theme when the user is eligible.
   *
   * @param options - Optional theme that should receive published changes.
   */
  @action
  enter({
    themeId,
  }: {
    /** Theme that should receive published changes, or `null` for no target. */
    themeId?: number | null;
  } = {}): void {
    if (!this.wireframeEditMode.canEdit) {
      return;
    }
    this.wireframeEditMode.activate();
    this.wireframeImageUpload.clearPending();
    this.wireframePublishTarget.setActiveTheme(themeId);
    // Swap in the editor-aware rich-text renderer so every richInline arg gains
    // its click-to-edit scaffold. The minimal (live-style) renderer is restored
    // in `exit()`. Icon args carry their own `data-block-arg` wrapper in the
    // block templates and don't need a swap. This MUST precede the draft seeding
    // below so the seeded drafts render against the scaffolded renderer.
    registerBlockArgRenderer("rich-text", ScaffoldedRichTextRenderer);
    // Hand off to the staging service: seed the editable draft layer now (so the
    // canvas paints immediately) and overlay any persisted per-user draft after
    // render.
    this.wireframeStaging.beginSession();

    // Warm the rich-text editor bundle in the background so the first
    // click-to-edit doesn't pay a load-the-PM-chunk latency hit. Webpack dedupes
    // dynamic-import promises by module id, so the controller's later
    // `loadInlineRichEditor()` resolves from cache even if the user enters edit
    // mode before this preload finishes.
    loadInlineRichEditor();

    // Warm every block's palette thumbnail now so the palette renders them
    // resolved (no loading skeleton) once it mounts a render cycle later.
    this.blocks.prefetchThumbnails();
  }

  /**
   * Re-discovers the outlets on the current page. The editor stays open across
   * SPA navigation, so an outlet that wasn't on the page at `enter()` (e.g.
   * `homepage-blocks` after navigating from the category page) needs the same
   * draft seeding `enter()` gives the entry page's outlets — otherwise it never
   * appears in the outline and can't be built. The `api.onPageChange` hook calls
   * this after every navigation.
   *
   * No-op when the editor isn't active. Idempotent: outlets already drafted this
   * session are skipped, so it's cheap to call on every page change.
   */
  @action
  rediscoverOutlets(): void {
    if (!this.wireframeEditMode.active) {
      return;
    }
    // Defer to after render so the just-navigated page's `<BlockOutlet>`s have
    // mounted and registered in the blocks service before the staging service
    // reads the mounted-outlet set that `editableOutlets` derives from.
    schedule(
      "afterRender",
      this.wireframeStaging,
      this.wireframeStaging.rediscover
    );
  }

  /** Closes the editing session and resets every session-scoped peer service. */
  @action
  exit(): void {
    // Tear down the staging session: flush the engine, drop every session-draft
    // layer, and clear the draft baseline / review-drawer state. Runs before the
    // peer resets below so the drafts are gone before the selection that pointed
    // into them is cleared.
    this.wireframeStaging.endSession();

    this.wireframeEditMode.deactivate();
    this.wireframePublishTarget.reset();
    // Tear the selection down WITHOUT firing the select hooks (flush args,
    // commit in-session edits, reveal-into-view) — they're meaningless once
    // the session is ending, and `selectBlock(null)` would fire them.
    this.wireframeSelection.reset();
    this.wireframeDragSession.clear();
    this.wireframeDragOverlay.clear();
    this.wireframeBlockReveal.reset();
    this.wireframeImageUpload.clearPending();
    // Revert to the minimal rich-text renderer so admin pages without
    // an open editor render the same DOM as live.
    resetBlockArgRenderer("rich-text");
    this.wireframeInspectorArgs.clear();
    this.wireframeForceExpand.reset();
  }

  /** Opens or closes the workspace according to its current active state. */
  @action
  toggle(): void {
    if (this.wireframeEditMode.active) {
      this.exit();
    } else {
      this.enter();
    }
  }
}
