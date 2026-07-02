// @ts-check
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import Service, { service } from "@ember/service";
import {
  registerBlockArgRenderer,
  resetBlockArgRenderer,
} from "discourse/blocks";
import loadInlineRichEditor from "discourse/lib/load-inline-rich-editor";
import ScaffoldedRichTextRenderer from "../components/scaffolded-rich-text-renderer";

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
  @service blocks;
  @service wireframeInspectorArgs;
  @service wireframeBlockReveal;
  @service wireframeDragOverlay;
  @service wireframeDragSession;
  @service wireframeForceExpand;
  @service wireframeImageUpload;
  @service wireframeSelection;
  @service wireframeEditMode;
  @service wireframeStaging;
  @service wireframePublishTarget;

  willDestroy() {
    super.willDestroy(...arguments);
    // Defensive: a session torn down without an explicit exit (e.g. the owner
    // being destroyed) should still drop any pending reveal/flash timer.
    this.wireframeBlockReveal.reset();
  }

  @action
  enter({ themeId } = {}) {
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
  rediscoverOutlets() {
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

  @action
  exit() {
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

  @action
  toggle() {
    if (this.wireframeEditMode.active) {
      this.exit();
    } else {
      this.enter();
    }
  }
}
