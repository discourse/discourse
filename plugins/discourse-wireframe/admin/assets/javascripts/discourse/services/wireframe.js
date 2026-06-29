// @ts-check
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { trackedMap } from "@ember/reactive/collections";
import { schedule } from "@ember/runloop";
import Service, { service } from "@ember/service";
import {
  registerBlockArgRenderer,
  resetBlockArgRenderer,
} from "discourse/blocks";
import {
  _clearLayoutLayer,
  _setLayoutLayer,
  LAYOUT_LAYERS,
} from "discourse/blocks/block-outlet";
import loadInlineRichEditor from "discourse/lib/load-inline-rich-editor";
import { i18n } from "discourse-i18n";
import ConflictModal from "../components/editor/conflict-modal";
import StaleDraftModal from "../components/editor/stale-draft-modal";
import ScaffoldedRichTextRenderer from "../components/scaffolded-rich-text-renderer";
import {
  cloneLayoutForDraft,
  normalizeImplicitChildren,
  serializeLayoutForSave,
  wrapAsOutletRoot,
} from "../lib/mutate-layout";
import { OUTLET_STATE } from "../services/wireframe-layout-query";

/**
 * Editor service. Holds the editor's session state and mediates the
 * in-memory mutation pipeline.
 *
 * Reactivity contract: every `@tracked` field on this service is read by the
 * panels and the canvas chrome. Mutating one re-renders the relevant pieces
 * via Glimmer's tracking system without manual notification.
 *
 * Mutation pipeline: at `enter()`, the editor deep-clones every outlet's
 * resolved layout and publishes those clones as the `session-draft` layer
 * (which wins over the persisted theme / code layer while editing). Edits during the
 * session mutate the draft entry's `args` (a `trackedObject`) directly —
 * the curried block reads through reactive getters defined by
 * `createBlockArgsWithReactiveGetters`, so a single `entry.args.title = "x"`
 * propagates to that block's specific text node without re-rendering the
 * layout structure or remounting the inspector form.
 *
 * Eager-on-enter (rather than lazy-on-first-edit) is the key trick: the
 * one-time layout-reference swap happens when the user clicks "Edit page",
 * which is a moment they expect a state transition. After that, no layer
 * switches happen until exit, so the canvas stays stable through every
 * keystroke.
 *
 * Discard / exit clears every session-draft layer the editor materialised,
 * leaving the underlying theme / code-default layers intact. Persistence
 * publishes the saved layout to the `theme` layer silently — the
 * session-draft is still resolved at that point, so the page doesn't
 * re-render at save time.
 */
export default class WireframeService extends Service {
  @service modal;
  @service wireframeArgEdit;
  @service wireframeBlockReveal;
  @service wireframeDrafts;
  @service wireframeDragOverlay;
  @service wireframeDragSession;
  @service wireframeEditEngine;
  @service wireframeForceExpand;
  @service wireframeImageUpload;
  @service wireframeInlineEdit;
  @service wireframeLayoutQuery;
  @service wireframePersistence;
  @service wireframeSelection;
  @service wireframeSession;
  @service wireframeTheme;

  /**
   * Whether the publish review surface (the save/publish drawer) is open. Held
   * here, not on a single chrome component, because several entry points open it
   * (the toolbar Save button, the publish-target indicator, the blocked callout).
   *
   * @type {boolean}
   */
  @tracked reviewDrawerOpen = false;

  /**
   * Whether the on-entry companion lookup is still in flight. Set true on entry
   * only when the bound theme can't be published to directly, then cleared once
   * the lookup settles (re-pointing `wireframeTheme.activeThemeId` to the
   * companion if one is found). The blocked callout and the indicator's blocked
   * state read this so
   * they don't flash during the brief lookup — the callout appears only once it's
   * settled that there is genuinely no companion.
   *
   * @type {boolean}
   */
  @tracked publishTargetResolving = false;

  /**
   * The serialized layout of each outlet's last *persisted draft* — set when a
   * saved draft is hydrated on entry and after each successful draft save, and
   * cleared when the draft is discarded, reset, or published. This is the
   * baseline for "are there unsaved draft edits?" — distinct from the engine's
   * pristine at-entry layout (used for discard and the publish-diff). It
   * lets the editor tell "the canvas differs from my saved draft" even when the
   * canvas happens to match the published layout. A `trackedMap` so the
   * `hasUnsavedDraftEdits` getter re-evaluates when a baseline changes.
   *
   * @type {Map<string, string>}
   */
  #persistedDraftLayouts = trackedMap();

  /**
   * Bumped on every `enter()` and `exit()`. The async draft hydration captures
   * the value at `enter()` time and bails if it no longer matches — so a
   * hydration whose fetch resolves after the user exited (or re-entered) never
   * writes into a closed or freshly-reopened session.
   *
   * @type {number}
   */
  #enterGeneration = 0;

  /**
   * Outlets whose persisted draft was based on an older live version than what
   * is published now, queued at hydration time for a one-at-a-time stale-draft
   * prompt (keep the draft, or start fresh from the live layout).
   *
   * @type {Array<{outlet: string, themeId: number, layout: Array<Object>}>}
   */
  #staleDraftQueue = [];

  willDestroy() {
    super.willDestroy(...arguments);
    // Defensive: a session torn down without an explicit exit (e.g. the owner
    // being destroyed) should still drop any pending reveal/flash timer.
    this.wireframeBlockReveal.reset();
  }

  /**
   * Whether any outlet's current layout differs from its last persisted draft —
   * i.e. there are edits that Save draft would write. Computed by comparing the
   * resolved layout against the persisted-draft baseline (or, for an outlet with
   * no saved draft yet, the published/underlying layout). Deliberately NOT derived
   * from `isDirty`: an outlet edited back to match the *published* layout drops out
   * of the published-diff bookkeeping, yet its *saved draft* still differs and must
   * remain saveable.
   *
   * @returns {boolean}
   */
  get hasUnsavedDraftEdits() {
    const outlets = new Set([
      ...this.wireframeEditEngine.editedOutletNames(),
      ...this.#persistedDraftLayouts.keys(),
    ]);
    for (const outletName of outlets) {
      if (this.#outletHasUnsavedDraftEdits(outletName)) {
        return true;
      }
    }
    return false;
  }

  /**
   * Whether the toolbar's Save control should be enabled — there is something to
   * publish (`isDirty`, i.e. the canvas differs from the published layout) OR an
   * unsaved draft change to write. The two are distinct: a draft reverted to match
   * the published layout is not publishable but still has a draft to save.
   *
   * @returns {boolean}
   */
  get canOpenReview() {
    return this.wireframeEditEngine.isDirty || this.hasUnsavedDraftEdits;
  }

  /**
   * Whether one outlet's current layout differs from the state Save draft would
   * have persisted: its last saved draft when one exists, otherwise the published
   * (underlying-layer) layout.
   *
   * @param {string} outletName
   * @returns {boolean}
   */
  #outletHasUnsavedDraftEdits(outletName) {
    const current = this.#serializeBaseline(
      this.wireframeLayoutQuery.readResolvedLayout(outletName)
    );
    const baseline = this.#persistedDraftLayouts.has(outletName)
      ? this.#persistedDraftLayouts.get(outletName)
      : this.#serializeBaseline(
          this.wireframeLayoutQuery.readResolvedLayout(outletName, {
            ignoreSessionDraft: true,
          })
        );
    return current !== baseline;
  }

  /**
   * Canonical serialization of a resolved layout for baseline comparison — the
   * same shape a draft/publish would persist, so two layouts that would save
   * identically compare equal regardless of in-memory identity (`__stableKey`).
   *
   * @param {Array<Object>|null} layout
   * @returns {string}
   */
  #serializeBaseline(layout) {
    return JSON.stringify(serializeLayoutForSave(layout ?? []));
  }

  /** Opens the publish review surface. */
  @action
  openReviewDrawer() {
    this.reviewDrawerOpen = true;
  }

  /** Closes the publish review surface. */
  @action
  closeReviewDrawer() {
    this.reviewDrawerOpen = false;
  }

  @action
  enter({ themeId } = {}) {
    if (!this.wireframeSession.canEdit) {
      return;
    }
    this.wireframeSession.activate();
    this.wireframeImageUpload.clearPending();
    // New session generation: invalidates any draft hydration still in flight
    // from a previous enter/exit so it can't write into this session.
    const generation = ++this.#enterGeneration;
    this.wireframeTheme.setActiveTheme(themeId);
    // A theme that can't be published to directly may have a companion to retarget/
    // to; suppress the blocked callout until the after-render lookup settles.
    this.publishTargetResolving =
      this.wireframeTheme.activeThemeTarget?.publishable === false;
    document.body.classList.add("wireframe-active");
    // Swap in the editor-aware rich-text renderer so every richInline
    // arg gains its click-to-edit scaffold. The minimal (live-style)
    // renderer is restored in `exit()`. Icon args carry their own
    // `data-block-arg` wrapper in the block templates and don't need
    // a swap.
    registerBlockArgRenderer("rich-text", ScaffoldedRichTextRenderer);
    this.#materializeAllDrafts();

    // Seed each outlet from the live layout first (above) so the canvas paints
    // immediately and `enter()` stays synchronous; then, after render, overlay
    // any persisted per-user draft. The fetch is fire-and-forget and
    // generation-guarded — it never blocks entry and bails if the session ends.
    schedule("afterRender", this, this.#hydrateDrafts, generation);

    // Warm the inline-rich-text editor bundle in the background so the
    // first click-to-edit doesn't pay a load-the-PM-chunk latency hit.
    // Webpack dedupes dynamic-import promises by module id, so the
    // controller's later `loadInlineRichEditor()` resolves from cache
    // even if the user enters edit mode before this preload finishes.
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
    // mounted and registered in the blocks service before we read the
    // mounted-outlet set that `editableOutlets` derives from.
    schedule("afterRender", this, this.#rediscoverMountedOutlets);
  }

  /**
   * The deferred body of `rediscoverOutlets` — runs once the new page's outlets
   * have mounted.
   */
  #rediscoverMountedOutlets() {
    // The session may have ended (or the page changed again) between scheduling
    // and running.
    if (!this.wireframeSession.active) {
      return;
    }
    const materialized = this.#materializeAllDrafts();
    // Only refetch persisted drafts when a fresh outlet was actually seeded —
    // navigating between pages that share outlets shouldn't trigger a fetch.
    if (materialized > 0) {
      this.#hydrateDrafts(this.#enterGeneration);
    }
  }

  @action
  exit() {
    // Flush the engine's session edit state: it writes any in-memory arg
    // snapshots back into their entries (a no-op for the production path with
    // session-drafts active, but restores directly-mutated code-default entries
    // so test isolation holds), clears every undo/dirty structure, and returns
    // the outlets it had drafted so we can drop their draft layers below.
    const draftedOutlets = this.wireframeEditEngine.flushSnapshotsAndReset();

    // Clear session-drafts. The underlying theme/code-default layer becomes
    // resolved again, displaying whatever was there before the editor
    // opened — in-memory mutations live ONLY on draft entries, so dropping
    // the drafts discards the mutations cleanly.
    for (const outletName of draftedOutlets) {
      _clearLayoutLayer(outletName, LAYOUT_LAYERS.SESSION_DRAFT);
    }
    this.wireframeLayoutQuery.clearOutletRoots();
    // Invalidate any in-flight draft hydration and drop queued stale prompts.
    this.#enterGeneration++;
    this.#staleDraftQueue.length = 0;

    this.wireframeSession.deactivate();
    this.reviewDrawerOpen = false;
    this.publishTargetResolving = false;
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
    this.#persistedDraftLayouts.clear();
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

  /**
   * Discards one outlet's unsaved edits: rolls its session draft back to the
   * pristine pre-edit layout (in memory) and deletes the caller's persisted
   * draft for it. Does NOT touch the live field — the published layout is
   * unaffected.
   *
   * @param {string} outletName
   * @returns {Promise<void>}
   */
  @action
  async discardOutlet(outletName) {
    this.wireframeEditEngine.rollbackOutletInMemory(outletName);
    this.#persistedDraftLayouts.delete(outletName);
    // Drop the outlet's own undo/redo history so a later undo can't resurrect a
    // draft we just discarded.
    this.wireframeEditEngine.dropUndoEntriesForOutlet(outletName);
    await this.wireframeDrafts.deleteDraft(
      this.wireframeTheme.outletOwner(outletName).themeId ??
        this.wireframeTheme.defaultThemeId,
      outletName
    );
  }

  /**
   * Discards every outlet's unsaved edits (the global toolbar affordance).
   * Iterates `discardOutlet` so persisted drafts are dropped too — never a
   * live-field delete.
   *
   * @returns {Promise<boolean>}
   */
  @action
  async discardAll() {
    if (!this.wireframeEditEngine.isDirty) {
      return false;
    }
    for (const outletName of this.wireframeEditEngine.editedOutletNames()) {
      await this.discardOutlet(outletName);
    }
    this.wireframeEditEngine.clearStacks();
    return true;
  }

  /**
   * Resets a published outlet to its default: deletes the live `block_layout`
   * field (via the persistence service), drops the caller's draft, clears the
   * local theme + session-draft layers so the underlying code default resolves,
   * then re-seeds a fresh editable draft from it. Only valid for a PUBLISHED
   * outlet whose owner is not Git-managed.
   *
   * @param {string} outletName
   * @returns {Promise<boolean>} false when the outlet isn't eligible.
   */
  @action
  async resetToDefault(outletName) {
    const owner = this.wireframeTheme.outletOwner(outletName);
    if (
      this.wireframeLayoutQuery.outletState(outletName) !==
        OUTLET_STATE.PUBLISHED ||
      owner.isGit
    ) {
      return false;
    }
    await this.wireframePersistence.resetToDefault(owner.themeId, outletName);
    await this.wireframeDrafts.deleteDraft(owner.themeId, outletName);

    // The live field and theme layer are gone; clear our session draft and edit
    // bookkeeping for this outlet so it resolves to the underlying default, then
    // re-seed a clean editable draft from that default (matching a fresh enter).
    _clearLayoutLayer(outletName, LAYOUT_LAYERS.SESSION_DRAFT);
    // Drop the engine's baseline + edit bookkeeping for this outlet; the
    // persisted-draft baseline is kernel-owned, cleared here.
    this.wireframeEditEngine.dropOutlet(outletName);
    this.#persistedDraftLayouts.delete(outletName);
    this.#materializeAllDrafts();
    return true;
  }

  /**
   * Publishes every edited outlet (the toolbar Save). Each region goes live on
   * the theme that owns it. Returns a banner message for non-conflict errors,
   * or null on success; stale-version conflicts are surfaced through the
   * conflict prompt here.
   *
   * @returns {Promise<string|null>}
   */
  @action
  async publishEditedOutlets() {
    const result = await this.wireframePersistence.publish(
      this.wireframeTheme.activeThemeId
    );
    return this.#processPublishResult(result);
  }

  /**
   * Publishes a single outlet to its owner theme (the inspector's per-outlet
   * Publish). Shares the conflict + reconciliation handling with the toolbar
   * Save.
   *
   * @param {string} outletName
   * @returns {Promise<string|null>} a banner message, or null on success.
   */
  @action
  async publishOutlet(outletName) {
    const result = await this.wireframePersistence.publishOutlet(
      outletName,
      this.wireframeTheme.activeThemeId
    );
    return this.#processPublishResult(result);
  }

  /**
   * Saves every outlet with unsaved draft edits as a private draft — the toolbar's
   * global Save draft. Drafts never go live. Iterates the outlets whose current
   * layout differs from their persisted draft (not just the published-diff set):
   * an outlet edited back to match the published layout is dropped from the
   * published-diff bookkeeping but its saved draft still differs, so it must be
   * written. A per-outlet failure is collected rather than thrown, so one bad
   * outlet doesn't abort drafting the rest.
   *
   * @returns {Promise<string|null>} a banner message listing any failures, or null on success.
   */
  @action
  async saveAllEditedDrafts() {
    const errors = [];
    const outlets = new Set([
      ...this.wireframeEditEngine.editedOutletNames(),
      ...this.#persistedDraftLayouts.keys(),
    ]);
    for (const outletName of outlets) {
      if (!this.#outletHasUnsavedDraftEdits(outletName)) {
        continue;
      }
      try {
        await this.saveDraftOutlet(outletName);
      } catch (error) {
        errors.push(`${outletName}: ${this.#describeSaveError(error)}`);
      }
    }
    if (errors.length === 0) {
      // Every saved outlet advanced its draft baseline, so Save draft reads as
      // clean until the next change.
      return null;
    }
    return errors.join("; ");
  }

  /**
   * Saves a single outlet as a private, never-live draft (the inspector's Save
   * draft). The outlet stays edited — a draft doesn't go live.
   *
   * @param {string} outletName
   * @returns {Promise<void>}
   */
  @action
  async saveDraftOutlet(outletName) {
    await this.wireframeDrafts.saveDraftOutlet(
      this.wireframeTheme.activeThemeId,
      outletName
    );
    // The persisted draft now matches the canvas — advance the baseline so the
    // outlet reads as having no unsaved draft edits until the next change.
    this.#persistedDraftLayouts.set(
      outletName,
      this.#serializeBaseline(
        this.wireframeLayoutQuery.readResolvedLayout(outletName)
      )
    );
  }

  /**
   * Exports one outlet's layout as a downloadable repo file (the Git escape
   * hatch for committing upstream). Exports the current draft when the outlet
   * has edits, otherwise the live field.
   *
   * @param {string} outletName
   * @returns {Promise<string|null>} an error message for the banner, or null on success.
   */
  @action
  async exportOutlet(outletName) {
    const themeId =
      this.wireframeTheme.outletOwner(outletName).themeId ??
      this.wireframeTheme.defaultThemeId;
    try {
      await this.wireframePersistence.exportOutlet(themeId, outletName, {
        useDraft: this.wireframeEditEngine.isOutletEdited(outletName),
      });
      return null;
    } catch (error) {
      return this.#gitActionError(error, "wireframe.outlet.export_failed");
    }
  }

  /**
   * Duplicates the active theme into a new editable copy carrying all edited
   * outlets' drafts. Returns the new theme id (the caller navigates to it) or an
   * error message — never navigates itself, so it stays testable.
   *
   * @returns {Promise<{themeId: (number|undefined), error: (string|undefined)}>}
   */
  @action
  async duplicateForEditing() {
    try {
      const { theme_id } = await this.wireframePersistence.duplicateTheme(
        this.wireframeTheme.activeThemeId
      );
      return { themeId: theme_id };
    } catch (error) {
      return {
        error: this.#gitActionError(error, "wireframe.outlet.duplicate_failed"),
      };
    }
  }

  /**
   * Creates (or reuses) a local customization component for the active Git theme
   * carrying all edited outlets' drafts. Returns the component's theme id (the
   * caller reloads so its override takes effect) or an error message.
   *
   * @returns {Promise<{themeId: (number|undefined), error: (string|undefined)}>}
   */
  @action
  async createCustomizationComponent() {
    try {
      const { theme_id } =
        await this.wireframePersistence.createCustomizationComponent(
          this.wireframeTheme.activeThemeId
        );
      return { themeId: theme_id };
    } catch (error) {
      return {
        error: this.#gitActionError(
          error,
          "wireframe.outlet.create_component_failed"
        ),
      };
    }
  }

  // Pulls the server's error message out of a failed git-action request, falling
  // back to a generic localized string.
  #gitActionError(error, fallbackKey) {
    const messages = error?.jqXHR?.responseJSON?.errors;
    return messages?.length ? messages.join(", ") : i18n(fallbackKey);
  }

  /**
   * Clears one outlet's dirty bookkeeping after it has been published — drops
   * its arg snapshots and edited flags WITHOUT rolling the layout back (the
   * published draft stays on the canvas). Unlike `discardOutlet`, nothing
   * reverts; this just reconciles "no unsaved changes" for that outlet.
   *
   * @param {string} outletName
   */
  #clearOutletEditState(outletName) {
    this.wireframeEditEngine.clearOutletEditState(outletName);
    // Publishing deletes the server-side draft, so its baseline no longer applies.
    this.#persistedDraftLayouts.delete(outletName);
  }

  /**
   * Reconciles a publish result: clears the edit state of published outlets,
   * runs the conflict prompt for any stale-version 409, drops undo/redo history
   * once nothing is left edited, and returns a banner message for the remaining
   * (non-conflict) errors.
   *
   * @param {{saved: Array<Object>, errors: Array<Object>}} result
   * @returns {Promise<string|null>}
   */
  async #processPublishResult(result) {
    for (const saved of result.saved) {
      this.#clearOutletEditState(saved.outlet);
    }
    for (const conflict of result.errors.filter((error) => error.conflict)) {
      await this.#resolvePublishConflict(conflict);
    }
    // Undo/redo references draft entries that no longer exist once everything is
    // published; clear it only when nothing is left edited, so a partial publish
    // keeps history for the outlets still open.
    if (this.wireframeEditEngine.editedOutletsSize === 0) {
      this.wireframeEditEngine.clearStacks();
    }
    const otherErrors = result.errors.filter((error) => !error.conflict);
    if (otherErrors.length === 0) {
      return null;
    }
    return otherErrors
      .map((error) => `${error.outlet}: ${error.message}`)
      .join("; ");
  }

  /**
   * Surfaces a stale-version conflict for one outlet. Overwrite republishes
   * against the server's current version (intentionally winning); cancel or
   * dismiss keeps the outlet edited for manual reconciliation.
   *
   * @param {Object} conflict - one conflict entry from a publish result.
   */
  async #resolvePublishConflict(conflict) {
    const result = await this.modal.show(ConflictModal, {
      model: { outlet: conflict.outlet, publishedAt: conflict.publishedAt },
    });
    if (result?.choice !== "overwrite") {
      return;
    }
    const ok = await this.wireframePersistence.overwriteOutlet(
      conflict.outlet,
      conflict.themeId,
      conflict.currentVersion
    );
    if (ok) {
      this.#clearOutletEditState(conflict.outlet);
    }
  }

  /**
   * Turns a thrown save-draft failure into a human-readable banner string. The
   * ajax helper rejects with `{ jqXHR, textStatus, errorThrown }` — an object
   * with no `message` — so a bare `error.message` read would always fall back to
   * a generic string and hide the real cause. Prefers the server's `errors`
   * array, then the HTTP status, then any thrown Error's message/name, and only
   * as a last resort the stringified value.
   *
   * @param {*} error - the value thrown/rejected from the draft save.
   * @returns {string} a non-empty description for the banner.
   */
  #describeSaveError(error) {
    const serverErrors = error?.jqXHR?.responseJSON?.errors;
    if (serverErrors?.length) {
      return serverErrors.join(", ");
    }
    if (error?.jqXHR) {
      return `HTTP ${error.jqXHR.status}`;
    }
    return error?.message || error?.name || String(error);
  }

  /**
   * Eagerly publishes a `session-draft` layer for every outlet that has a
   * resolved layout. After this runs, `_getResolvedLayouts()` returns draft
   * entries for those outlets — the rest of the editor session mutates
   * those drafts in place via `trackedObject`, so no further layer swap
   * happens during typing.
   *
   * Idempotent: running over already-drafted outlets is a no-op (skipped by
   * the `draftedOutlets` check). Invoked from `enter()` and, for outlets that
   * mount later, from `rediscoverOutlets()` on navigation.
   *
   * @returns {number} How many outlets were newly drafted by this call. Lets
   *   the navigation path skip a redundant draft refetch when nothing new
   *   mounted.
   */
  #materializeAllDrafts() {
    let materialized = 0;
    for (const outletName of this.wireframeLayoutQuery.editableOutlets) {
      if (this.wireframeEditEngine.isOutletDrafted(outletName)) {
        continue;
      }
      // A LOCKED outlet is owned by a non-overridable programmatic layout: it
      // stays read-only, so never seed a draft for it (the outline still lists
      // it via `editableOutlets`, but the chrome marks it non-editable).
      if (
        this.wireframeLayoutQuery.outletState(outletName) ===
        OUTLET_STATE.LOCKED
      ) {
        continue;
      }
      const layout = this.wireframeLayoutQuery.readResolvedLayout(outletName);
      // Outlets that are mounted but have no registered layout get an
      // empty draft seeded here, so the outline lists them with zero
      // rows and the canvas accepts drops on the outlet boundary
      // immediately. Without this seed an empty outlet would only get
      // a draft the first time something tried to write to it.
      //
      // `wrapAsOutletRoot` normalises the draft to a single root `layout`
      // block so the outlet renders as an implicit layout (selectable, with
      // a switchable mode). A flat list renders identically to the default
      // stack, so the wrap is visually transparent until the author changes
      // the mode.
      // Wrap any non-conforming child of an implicit-child-kind container (e.g.
      // a hand-authored non-layout tab panel) so the invariant holds from the
      // moment the editor opens, matching what `publishStructuralChange` keeps
      // up during editing.
      const draftLayout = normalizeImplicitChildren(
        wrapAsOutletRoot(layout ? cloneLayoutForDraft(layout) : []),
        (ref) => this.wireframeLayoutQuery.lookupBlockMetadata(ref)
      );
      _setLayoutLayer(
        outletName,
        LAYOUT_LAYERS.SESSION_DRAFT,
        draftLayout,
        getOwner(this),
        // Permissive validation: while the editor is open the user may
        // produce intermediate invalid states (an empty container after
        // a drag, a typo, a missing required arg). Strict validation
        // would throw and crash the page; permissive marks the
        // validation as warned and keeps the layout rendering.
        { permissive: true }
      );
      this.wireframeEditEngine.markOutletDrafted(outletName);
      materialized++;
      // Record the root layout's key (minted by the publish above) so
      // selection / chrome can recognise it as the outlet.
      this.wireframeLayoutQuery.recordOutletRoot(outletName);
      // Rollback target for `resetAll()`. Cloned from the just-published
      // draft (not the pre-wrap layout) so it carries the normalised shape
      // and the minted root `__stableKey` — that keeps the recorded root key
      // valid after a reset re-publishes this snapshot. A separate clone so
      // in-place arg mutations on the draft never leak into the snapshot.
      this.wireframeEditEngine.captureBaseline(
        outletName,
        cloneLayoutForDraft(
          this.wireframeLayoutQuery.readResolvedLayout(outletName) ?? []
        )
      );
    }
    return materialized;
  }

  /**
   * When the bound theme can't be published to directly, look up its companion
   * component and re-point `wireframeTheme.activeThemeId` to it — so the editor targets the
   * publishable companion the user already set up instead of the unpublishable
   * parent. A no-op (and clears the resolving flag) when the theme is already
   * publishable or has no companion. Generation-guarded so a late lookup never
   * writes into a new session.
   *
   * @param {number} generation
   * @returns {Promise<void>}
   */
  async #resolveCompanionTarget(generation) {
    const target = this.wireframeTheme.activeThemeTarget;
    if (!target || target.publishable) {
      this.publishTargetResolving = false;
      return;
    }
    const companionId = await this.wireframeDrafts.companionId(
      this.wireframeTheme.activeThemeId
    );
    if (generation !== this.#enterGeneration || !this.wireframeSession.active) {
      return;
    }
    if (companionId != null) {
      this.wireframeTheme.setActiveTheme(companionId);
    }
    this.publishTargetResolving = false;
  }

  /**
   * Overlays any persisted per-user draft on top of the freshly materialized
   * live seeds. Runs after render (off the synchronous `enter()`), so it never
   * blocks first paint, and is generation-guarded so a fetch that resolves after
   * the user exited or re-entered never writes into the wrong session. A failed
   * fetch degrades to "no drafts" (handled in the drafts service).
   *
   * @param {number} generation - the `#enterGeneration` captured at enter time.
   * @returns {Promise<void>}
   */
  async #hydrateDrafts(generation) {
    // Re-point to an existing companion BEFORE deriving theme ids, so default
    // outlets, the indicator, publish targeting, and the draft fetch below all
    // resolve against the companion the user already set up.
    await this.#resolveCompanionTarget(generation);
    if (generation !== this.#enterGeneration || !this.wireframeSession.active) {
      return;
    }
    const themeIds = [
      ...new Set(
        this.wireframeLayoutQuery.editableOutlets
          .map((name) => this.wireframeTheme.outletOwner(name).themeId)
          .filter((id) => id != null)
      ),
    ];
    const drafts = await this.wireframeDrafts.fetchDrafts(themeIds);
    // Bail if the user exited or re-entered while the fetch was in flight.
    if (generation !== this.#enterGeneration || !this.wireframeSession.active) {
      return;
    }

    const applied = [];
    for (const draft of drafts) {
      const { outlet } = draft;
      // Only hydrate outlets the editor is actually drafting and that the user
      // hasn't started touching since enter — re-seeding would clobber a live
      // edit (committed or still in flight).
      if (
        !this.wireframeEditEngine.isOutletDrafted(outlet) ||
        !this.#isOutletPristineSinceEnter(outlet)
      ) {
        continue;
      }
      const liveToken = this.wireframePersistence.tokenFor(
        draft.themeId,
        outlet
      );
      if ((draft.baseVersionToken ?? "") === liveToken) {
        // The draft is based on the live version that's still current: apply it.
        this.#applyDraftToOutlet(outlet, draft.layout);
        applied.push(outlet);
      } else {
        // The live layout moved on since the draft was saved: prompt the user.
        this.#staleDraftQueue.push(draft);
      }
    }

    // Each re-seeded outlet recorded its draft baseline in `#applyDraftToOutlet`,
    // so it reads as having no unsaved draft edits until the next change; an outlet
    // touched by a live edit during the fetch has no baseline and is compared
    // against the published layout instead, so a genuine edit stays saveable.
    await this.#flushStaleDraftQueue(generation);
  }

  /**
   * Re-seeds an outlet's session draft from a persisted draft layout and marks
   * the outlet edited (so it is dirty, badged as editing, and a Save/Publish
   * target). Leaves the engine's pristine baseline untouched — it still holds
   * the live clone, so a later discard reverts to the published layout, not the
   * draft.
   *
   * @param {string} outlet
   * @param {Array<Object>} layout - the persisted draft layout.
   */
  #applyDraftToOutlet(outlet, layout) {
    const draftLayout = normalizeImplicitChildren(
      wrapAsOutletRoot(cloneLayoutForDraft(layout ?? [])),
      (ref) => this.wireframeLayoutQuery.lookupBlockMetadata(ref)
    );
    _setLayoutLayer(
      outlet,
      LAYOUT_LAYERS.SESSION_DRAFT,
      draftLayout,
      getOwner(this),
      { permissive: true }
    );
    this.wireframeLayoutQuery.recordOutletRoot(outlet);
    this.wireframeEditEngine.markOutletStructurallyEdited(outlet);
    // Record what the saved draft holds, so an edit that returns the canvas to the
    // published layout is still recognized as differing from the persisted draft.
    this.#persistedDraftLayouts.set(
      outlet,
      this.#serializeBaseline(
        this.wireframeLayoutQuery.readResolvedLayout(outlet)
      )
    );
  }

  /**
   * Whether an outlet is untouched since `enter()` — safe to overlay a draft
   * onto. Conservative: any committed edit, pending arg flush, or open inline
   * edit anywhere blocks re-seeding so live work is never clobbered.
   *
   * @param {string} outlet
   * @returns {boolean}
   */
  #isOutletPristineSinceEnter(outlet) {
    return (
      !this.wireframeEditEngine.isOutletEdited(outlet) &&
      !this.wireframeArgEdit.hasPending &&
      this.wireframeInlineEdit.blockKey == null
    );
  }

  /**
   * Prompts for each stale draft one at a time (chained on the modal's
   * close promise so they never overlap). Keep re-seeds from the draft; start
   * fresh drops the persisted draft and keeps the already-seeded live layout.
   * Generation-guarded between prompts so exiting mid-queue stops it.
   *
   * @param {number} generation - the `#enterGeneration` captured at enter time.
   * @returns {Promise<void>}
   */
  async #flushStaleDraftQueue(generation) {
    while (this.#staleDraftQueue.length > 0) {
      if (generation !== this.#enterGeneration) {
        return;
      }
      const item = this.#staleDraftQueue.shift();
      const result = await this.modal.show(StaleDraftModal, {
        model: { outlet: item.outlet },
      });
      if (generation !== this.#enterGeneration) {
        return;
      }
      if (result?.choice === "keep") {
        this.#applyDraftToOutlet(item.outlet, item.layout);
      } else if (result?.choice === "fresh") {
        // Start fresh: the live seed is already in place; drop the stale draft.
        this.wireframeDrafts.deleteDraft(item.themeId, item.outlet);
      }
      // Dismissed (no choice): keep the live seed and leave the draft in place
      // so the prompt returns next session.
    }
  }
}
