// @ts-check
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import Service, { service } from "@ember/service";
import {
  registerBlockArgRenderer,
  resetBlockArgRenderer,
} from "discourse/blocks";
import {
  _clearLayoutLayer,
  LAYOUT_LAYERS,
} from "discourse/blocks/block-outlet";
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
export default class WireframeService extends Service {
  @service wireframeArgEdit;
  @service wireframeBlockReveal;
  @service wireframeDragOverlay;
  @service wireframeDragSession;
  @service wireframeEditEngine;
  @service wireframeForceExpand;
  @service wireframeImageUpload;
  @service wireframeLayoutQuery;
  @service wireframeSelection;
  @service wireframeSession;
  @service wireframeStaging;
  @service wireframeTheme;

  willDestroy() {
    super.willDestroy(...arguments);
    // Defensive: a session torn down without an explicit exit (e.g. the owner
    // being destroyed) should still drop any pending reveal/flash timer.
    this.wireframeBlockReveal.reset();
  }

  @action
  enter({ themeId } = {}) {
    if (!this.wireframeSession.canEdit) {
      return;
    }
    this.wireframeSession.activate();
    this.wireframeImageUpload.clearPending();
    this.wireframeTheme.setActiveTheme(themeId);
    document.body.classList.add("wireframe-active");
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

    // Warm the inline-rich-text editor bundle in the background so the first
    // click-to-edit doesn't pay a load-the-PM-chunk latency hit. Webpack dedupes
    // dynamic-import promises by module id, so the controller's later
    // `loadInlineRichEditor()` resolves from cache even if the user enters edit
    // mode before this preload finishes.
    loadInlineRichEditor();
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
    if (!this.wireframeSession.active) {
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
    // Flush the engine's session edit state and drop every session-draft layer
    // it seeded. `flushSnapshotsAndReset` writes any in-memory arg snapshots back
    // into their entries (a no-op for the production path with session-drafts
    // active, but restores directly-mutated code-default entries so test
    // isolation holds), clears the undo/dirty structures, and returns the
    // drafted outlets so their draft layers can be cleared — the underlying
    // theme/code-default layer then resolves again, discarding the in-memory
    // mutations cleanly. Runs before the peer resets below so the drafts are gone
    // before the selection that pointed into them is cleared.
    const draftedOutlets = this.wireframeEditEngine.flushSnapshotsAndReset();
    for (const outletName of draftedOutlets) {
      _clearLayoutLayer(outletName, LAYOUT_LAYERS.SESSION_DRAFT);
    }
    this.wireframeLayoutQuery.clearOutletRoots();
    // Clear the staging service's own session state (draft baseline, generation
    // guard, stale-draft queue, review-drawer state).
    this.wireframeStaging.endSession();

    this.wireframeSession.deactivate();
    this.wireframeTheme.reset();
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
    this.wireframeArgEdit.clear();
    this.wireframeForceExpand.reset();
    // Clear every editor body class, including the chrome's collapse / dim
    // modifiers. These are separate class tokens from `wireframe-active`, so
    // leaving them would keep the live page dimmed after the editor closes.
    document.body.classList.remove(
      "wireframe-active",
      "wireframe-active--left-collapsed",
      "wireframe-active--right-collapsed",
      "wireframe-active--dim-non-editable"
    );
  }

  @action
  toggle() {
    if (this.wireframeSession.active) {
      this.exit();
    } else {
      this.enter();
    }
  }
}
