import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { schedule } from "@ember/runloop";
import Service, { service } from "@ember/service";
import {
  _clearLayoutLayer,
  _setLayoutLayer,
  LAYOUT_LAYERS,
} from "discourse/blocks/block-outlet";
import { withPluginApi } from "discourse/lib/plugin-api";
import type ModalService from "discourse/services/modal";
import { i18n } from "discourse-i18n";
import ConflictModal from "discourse/plugins/discourse-wireframe/discourse/components/editor/publish/conflict-modal";
import {
  cloneLayoutForDraft,
  normalizeImplicitChildren,
  wrapAsOutletRoot,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";
import { isInRenderedStack, previewDesign } from "../lib/design-preview";
import type WireframeDraftsService from "./wireframe-drafts";
import type WireframeEditModeService from "./wireframe-edit-mode";
import type WireframeImageCompositionService from "./wireframe-image-composition";
import WireframeLayoutQueryService, {
  OUTLET_STATE,
} from "./wireframe-layout-query";
import type WireframeLiveLayoutService from "./wireframe-live-layout";
import type WireframeMutationEngineService from "./wireframe-mutation-engine";
import type WireframePublishTargetService from "./wireframe-publish-target";

/**
 * The outcome of creating a design: the new design's id, or an error message for
 * the banner. Exactly one field is populated.
 */
type DesignActionResult = {
  /** Newly created design, when the action succeeds. */
  themeId?: number;
  /** Message shown when the action fails. */
  error?: string;
};

/** One outlet's entry in a publish result — either published or failed. */
type PublishOutletError = {
  /** Outlet whose publish failed. */
  outlet: string;
  /** Theme to which the outlet was being published. */
  themeId: number;
  /** Human-readable failure message. */
  message: string;
  /** Whether the failure represents a version conflict. */
  conflict: boolean;
  /** Server's current version token, when the request conflicted. */
  currentVersion?: string;
  /** Server publish timestamp associated with the conflict. */
  publishedAt?: string;
};

/** A publish result, as consumed by the reconciliation step. */
type PublishResult = {
  /** Outlets successfully written by the publish request. */
  saved: Array<{
    /** Name of the successfully published outlet. */
    outlet: string;
  }>;
  /** Per-outlet failures returned by the publish request. */
  errors: PublishOutletError[];
};

/**
 * The shape of a rejected ajax request — an object with no `message`, so the
 * server error, then the HTTP status, are read before any thrown Error's
 * `message`/`name`.
 */
type AjaxError = {
  /** Underlying jQuery request metadata, when the rejection came from Ajax. */
  jqXHR?: {
    /** HTTP response status. */
    status?: number;
    /** Parsed JSON error response, when available. */
    responseJSON?: {
      /** Server-provided error messages. */
      errors?: string[];
    };
  };
  /** Error message supplied by a thrown value. */
  message?: string;
  /** Error class name supplied by a thrown value. */
  name?: string;
};

/**
 * The editor's staging area: the in-session editable draft layer plus the
 * workflow that commits or abandons it (publish / save draft / discard / reset).
 *
 * The "staging" framing: while the editor is open, every editable outlet gets a
 * `session-draft` layer seeded from its live layout (`beginSession`). The author
 * edits that draft in place; this service tracks how it differs from the last
 * saved draft (`#persistedDraftLayouts`) and from the published layout, and
 * exposes the commands that move a draft live (`publishEditedOutlets`), persist
 * it privately (`saveDraftOutlet`), or throw it away (`discardOutlet`). It also
 * owns the review-drawer state that surfaces those commands.
 *
 * It is a coordinator over the lower-level I/O peers — `wireframeDrafts`
 * (draft-endpoint I/O), `wireframeLiveLayout` (live-field I/O), and the
 * mutation/undo engine — never reaching up into the orchestrator that opens and
 * closes the session. The orchestrator drives this service one-way via
 * `beginSession`/`endSession`/`rediscover`; everything else is called by the
 * publish-review surfaces that inject it directly.
 */
export default class WireframeStagingService extends Service {
  /** Presents conflict decisions to the editor. */
  @service declare modal: ModalService;

  @service declare wireframeImageComposition: WireframeImageCompositionService;

  /** Looks up the theme's saved layouts. */
  @service declare wireframeDrafts: WireframeDraftsService;

  /** Tracks mutations, dirty outlets, snapshots, and undo state. */
  @service declare wireframeMutationEngine: WireframeMutationEngineService;

  /** Resolves editable outlets, layout entries, and block metadata. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;

  /** Reads and publishes live theme layouts. */
  @service declare wireframeLiveLayout: WireframeLiveLayoutService;

  /** Reports whether an editor session remains active. */
  @service declare wireframeEditMode: WireframeEditModeService;

  /** Resolves the active theme and per-outlet publish destinations. */
  @service declare wireframePublishTarget: WireframePublishTargetService;

  /**
   * Whether the on-entry companion lookup is still in flight. Set true at
   * `beginSession` only when the bound theme can't be published to directly, then
   * cleared once the lookup settles (re-pointing `wireframePublishTarget.activeThemeId` to
   * the companion if one is found). The blocked callout and the indicator's
   * blocked state read this so they don't flash during the brief lookup — the
   * callout appears only once it's settled that there is genuinely no companion.
   */
  @tracked publishTargetResolving = false;

  /**
   * Bumped on every `beginSession()` and `endSession()`. The async draft
   * hydration captures the value at begin time and bails if it no longer matches
   * — so a hydration whose fetch resolves after the user exited (or re-entered)
   * never writes into a closed or freshly-reopened session.
   */
  #generation = 0;

  /**
   * Opens the staging session: seeds an editable `session-draft` layer for every
   * outlet, then (after render) overlays any persisted per-user draft. Driven
   * one-way by the orchestrator's `enter()`.
   */
  beginSession(): void {
    // New session generation: invalidates any draft hydration still in flight
    // from a previous session so it can't write into this one.
    const generation = ++this.#generation;
    // The theme in use may have an installed design to retarget to; hold the
    // "unsaved design" state until the after-render lookup settles.
    this.publishTargetResolving =
      this.wireframePublishTarget.activeThemeTarget?.publishable === false;
    this.#materializeAllDrafts();

    // Re-point to a layout the theme already has once the canvas has painted, so
    // default outlets, the indicator and saving all target it. Fire-and-forget and
    // generation-guarded: it never blocks entry and bails if the session ends.
    schedule("afterRender", this, this.#resolveCompanionTarget, generation);
  }

  /**
   * Tears the staging session down (the mirror of `beginSession`). Flushes the
   * engine's edit state and drops every session-draft layer this seeded, so the
   * underlying theme/code-default layer resolves again — in-memory mutations live
   * ONLY on draft entries, so dropping the drafts discards them cleanly. Then
   * bumps the generation (which invalidates any lookup still in flight) and
   * resets the publish-target-resolving flag. Driven one-way by the
   * orchestrator's `exit()`.
   */
  endSession(): void {
    // `flushSnapshotsAndReset` writes any in-memory arg snapshots back into their
    // entries (a no-op for the production path with session-drafts active, but it
    // restores directly-mutated code-default entries so test isolation holds),
    // clears the undo/dirty structures, and returns the drafted outlets so their
    // draft layers can be cleared.
    const draftedOutlets =
      this.wireframeMutationEngine.flushSnapshotsAndReset();
    for (const outletName of draftedOutlets) {
      _clearLayoutLayer(outletName, LAYOUT_LAYERS.SESSION_DRAFT);
    }
    this.wireframeLayoutQuery.clearOutletRoots();
    this.#generation++;
    this.publishTargetResolving = false;
  }

  /**
   * Seeds drafts for outlets that mounted after `beginSession` (e.g. a new page's
   * outlet after SPA navigation). Scheduled after render by the orchestrator's
   * `rediscoverOutlets()`. Idempotent: outlets already drafted this session are
   * skipped, so it's cheap to call on every page change.
   */
  rediscover(): void {
    // The session may have ended (or the page changed again) between scheduling
    // and running.
    if (!this.wireframeEditMode.active) {
      return;
    }
    this.#materializeAllDrafts();
  }

  /**
   * Discards one outlet's unsaved edits: rolls its session draft back to the
   * pristine pre-edit layout (in memory). Does NOT touch the saved layout.
   *
   * @param outletName - Outlet whose draft edits should be discarded.
   */
  @action
  async discardOutlet(outletName: string): Promise<void> {
    this.wireframeMutationEngine.rollbackOutletInMemory(outletName);
    // Drop the outlet's own undo/redo history so a later undo can't resurrect an
    // edit we just discarded.
    this.wireframeMutationEngine.dropUndoEntriesForOutlet(outletName);
  }

  /**
   * Discards every outlet's unsaved edits (the global toolbar affordance).
   * Iterates `discardOutlet` so persisted drafts are dropped too — never a
   * live-field delete.
   */
  @action
  async discardAll(): Promise<boolean> {
    if (!this.wireframeMutationEngine.isDirty) {
      return false;
    }
    for (const outletName of this.wireframeMutationEngine.editedOutletNames()) {
      await this.discardOutlet(outletName);
    }
    this.wireframeMutationEngine.clearStacks();
    return true;
  }

  /**
   * Resets a published outlet to its default: deletes the live `block_layout`
   * field (via the live-layout service), drops the caller's draft, clears the
   * local theme + session-draft layers so the underlying code default resolves,
   * then re-seeds a fresh editable draft from it. Only valid for an outlet
   * published on the session's own design.
   *
   * @param outletName - Published outlet to reset to its underlying default.
   * @returns false when the outlet isn't eligible.
   */
  @action
  async resetToDefault(outletName: string): Promise<boolean> {
    const owner = this.wireframePublishTarget.outletOwner(outletName);
    if (
      this.wireframeLayoutQuery.outletState(outletName) !==
        OUTLET_STATE.PUBLISHED ||
      !this.wireframePublishTarget.hasDesign ||
      owner.themeId !== this.wireframePublishTarget.activeThemeId
    ) {
      return false;
    }
    await this.wireframeLiveLayout.resetToDefault(owner.themeId, outletName);

    // The live field and theme layer are gone; clear our session draft and edit
    // bookkeeping for this outlet so it resolves to the underlying default, then
    // re-seed a clean editable draft from that default (matching a fresh enter).
    _clearLayoutLayer(outletName, LAYOUT_LAYERS.SESSION_DRAFT);
    // Drop the engine's baseline + edit bookkeeping for this outlet.
    this.wireframeMutationEngine.dropOutlet(outletName);
    this.#materializeAllDrafts();
    return true;
  }

  /**
   * Publishes every edited outlet (the toolbar Save). Each region goes live on
   * the theme that owns it. Returns a banner message for non-conflict errors,
   * or null on success; stale-version conflicts are surfaced through the
   * conflict prompt here.
   */
  @action
  async publishEditedOutlets(): Promise<string | null> {
    if (this.wireframeImageComposition.target) {
      return i18n("wireframe.inspector.image.finish_adjustment");
    }
    const result = await this.wireframeLiveLayout.publish(
      this.wireframePublishTarget.activeThemeId
    );
    return this.#processPublishResult(result);
  }

  /**
   * Publishes a single outlet to its owner theme (the inspector's per-outlet
   * Publish). Shares the conflict + reconciliation handling with the toolbar
   * Save.
   *
   * @param outletName - Outlet to publish to its resolved owner theme.
   * @returns a banner message, or null on success.
   */
  @action
  async publishOutlet(outletName: string): Promise<string | null> {
    if (this.wireframeImageComposition.target) {
      return i18n("wireframe.inspector.image.finish_adjustment");
    }
    const result = await this.wireframeLiveLayout.publishOutlet(
      outletName,
      this.wireframePublishTarget.activeThemeId
    );
    return this.#processPublishResult(result);
  }

  /**
   * Creates a named design on the theme in use and binds the session to it, so
   * the next publish writes there. By default it starts empty and the edits are
   * published afterwards; with `withEdits` it is seeded with the edited outlets,
   * for a design created to hold a copy of the current work.
   *
   * @param name - Name the author gave the design.
   * @param options - Creation options.
   *   - `withEdits` - Seed the design with the edited outlets' drafts.
   * @returns The new design's id, or an error message for the banner.
   */
  @action
  async createDesign(
    name: string,
    {
      withEdits = false,
    }: {
      /** Whether to seed the design with the edited outlets' drafts. */
      withEdits?: boolean;
    } = {}
  ): Promise<DesignActionResult> {
    const parentId = this.wireframePublishTarget.parentThemeId;
    if (parentId == null) {
      return { error: i18n("wireframe.design.create_failed") };
    }
    try {
      const { theme_id } = await this.wireframeLiveLayout.createDesign(
        parentId,
        name,
        { withEdits }
      );
      // A new layout starts as a draft: saved, but not used by the theme.
      this.wireframePublishTarget.registerDesign(theme_id, name, {
        inUse: false,
      });
      if (!withEdits) {
        this.wireframePublishTarget.setActiveTheme(theme_id);
      }
      return { themeId: theme_id };
    } catch (error) {
      return {
        error: this.#designActionError(error, "wireframe.design.create_failed"),
      };
    }
  }

  /**
   * Renames the session's design. Before the design exists the name is only
   * remembered, and used when it is created on the first publish.
   *
   * @param name - The new name.
   * @returns An error message for the banner, or null on success.
   */
  @action
  async renameDesign(name: string): Promise<string | null> {
    const target = this.wireframePublishTarget.activeThemeTarget;
    if (!target?.publishable) {
      this.wireframePublishTarget.setPendingDesignName(name);
      return null;
    }
    try {
      await this.wireframeLiveLayout.renameDesign(target.themeId, name);
      this.wireframePublishTarget.registerDesign(target.themeId, name);
      return null;
    } catch (error) {
      return this.#designActionError(error, "wireframe.design.rename_failed");
    }
  }

  /**
   * Installs one of the theme's designs. Returns an error message, or null on
   * success; the caller reloads so the design's layouts take effect.
   *
   * @param designId - ID of the design to install.
   */
  @action
  async switchDesign(designId: number): Promise<string | null> {
    const parentId = this.wireframePublishTarget.parentThemeId;
    if (parentId == null) {
      return i18n("wireframe.design.switch_failed");
    }
    try {
      await this.wireframeLiveLayout.installDesign(parentId, designId);
      return null;
    } catch (error) {
      return this.#designActionError(error, "wireframe.design.switch_failed");
    }
  }

  /**
   * Clears one outlet's dirty bookkeeping after it has been published — drops
   * its arg snapshots and edited flags WITHOUT rolling the layout back (the
   * published draft stays on the canvas). Unlike `discardOutlet`, nothing
   * reverts; this just reconciles "no unsaved changes" for that outlet.
   *
   * @param outletName - Published outlet whose edit bookkeeping should clear.
   */
  #clearOutletEditState(outletName: string): void {
    this.wireframeMutationEngine.clearOutletEditState(outletName);
  }

  /**
   * Reconciles a publish result: clears the edit state of published outlets,
   * runs the conflict prompt for any stale-version 409, drops undo/redo history
   * once nothing is left edited, and returns a banner message for the remaining
   * (non-conflict) errors.
   *
   * @param result - Per-outlet successes and failures returned by publish.
   */
  async #processPublishResult(result: PublishResult): Promise<string | null> {
    for (const saved of result.saved) {
      this.#clearOutletEditState(saved.outlet);
    }
    for (const conflict of result.errors.filter((error) => error.conflict)) {
      await this.#resolvePublishConflict(conflict);
    }
    // Undo/redo references draft entries that no longer exist once everything is
    // published; clear it only when nothing is left edited, so a partial publish
    // keeps history for the outlets still open.
    if (this.wireframeMutationEngine.editedOutletsSize === 0) {
      this.wireframeMutationEngine.clearStacks();
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
   * @param conflict - one conflict entry from a publish result.
   */
  async #resolvePublishConflict(conflict: PublishOutletError): Promise<void> {
    const result = await this.modal.show(ConflictModal, {
      model: { outlet: conflict.outlet, publishedAt: conflict.publishedAt },
    });
    if (result?.choice !== "overwrite" || !conflict.currentVersion) {
      return;
    }
    const ok = await this.wireframeLiveLayout.overwriteOutlet(
      conflict.outlet,
      conflict.themeId,
      conflict.currentVersion
    );
    if (ok) {
      this.#clearOutletEditState(conflict.outlet);
    }
  }

  /**
   * Extracts a server message from a failed Git action, falling back to a
   * localized generic message.
   *
   * @param error - Rejected request details returned by the Git action.
   * @param fallbackKey - Translation key used when the response has no errors.
   * @returns The message suitable for the editor error banner.
   */
  #designActionError(error: AjaxError, fallbackKey: string): string {
    const messages = error?.jqXHR?.responseJSON?.errors;
    return messages?.length ? messages.join(", ") : i18n(fallbackKey);
  }

  /**
   * Eagerly seeds a `session-draft` layer for every outlet that has a resolved
   * layout. After this runs, resolving an outlet's layout yields its session-draft
   * entries instead of the underlying theme/code-default layer — the rest of the
   * editor session mutates those drafts in place via `trackedObject`, so no
   * further layer swap happens during typing.
   *
   * Idempotent: running over already-drafted outlets is a no-op (skipped by the
   * `isOutletDrafted` check). Invoked from `beginSession()` and, for outlets that
   * mount later, from `rediscover()` on navigation.
   *
   * @returns How many outlets were newly drafted by this call. Lets
   *   the navigation path skip a redundant draft refetch when nothing new
   *   mounted.
   */
  #materializeAllDrafts(): number {
    let materialized = 0;
    for (const outletName of this.wireframeLayoutQuery.editableOutlets) {
      if (this.wireframeMutationEngine.isOutletDrafted(outletName)) {
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
      this.wireframeMutationEngine.markOutletDrafted(outletName);
      materialized++;
      // Record the root layout's key (minted by the publish above) so
      // selection / chrome can recognise it as the outlet.
      this.wireframeLayoutQuery.recordOutletRoot(outletName);
      // Rollback target for `resetAll()`. Cloned from the just-published
      // draft (not the pre-wrap layout) so it carries the normalised shape
      // and the minted root `__stableKey` — that keeps the recorded root key
      // valid after a reset re-publishes this snapshot. A separate clone so
      // in-place arg mutations on the draft never leak into the snapshot.
      this.wireframeMutationEngine.captureBaseline(
        outletName,
        cloneLayoutForDraft(
          this.wireframeLayoutQuery.readResolvedLayout(outletName) ?? []
        )
      );
    }
    return materialized;
  }

  /**
   * When the session is bound to the theme in use rather than a design, look up
   * the theme's installed design and re-point
   * `wireframePublishTarget.activeThemeId` to it — so the editor targets the
   * design the user already set up. A no-op (and clears the resolving flag) when
   * the session is already on a design or none is installed. Generation-guarded so a late
   * lookup never writes into a new session.
   *
   * @param generation - Session generation captured before the async lookup.
   */
  async #resolveCompanionTarget(generation: number): Promise<void> {
    const target = this.wireframePublishTarget.activeThemeTarget;
    if (!target || target.publishable) {
      this.publishTargetResolving = false;
      return;
    }
    const { installedId, currentId } = await this.wireframeDrafts.fetchDesigns(
      target.themeId
    );
    if (generation !== this.#generation || !this.wireframeEditMode.active) {
      return;
    }
    if (currentId != null) {
      this.wireframePublishTarget.setActiveTheme(currentId);
      this.wireframePublishTarget.markDesignInUse(
        currentId,
        currentId === installedId
      );
      // A saved layout the theme doesn't use isn't on the page, so load it for
      // this session and seed the canvas from it.
      if (currentId !== installedId && !isInRenderedStack(currentId)) {
        await this.#loadUnusedDesign(currentId);
        if (generation !== this.#generation || !this.wireframeEditMode.active) {
          return;
        }
        this.#reseedCleanOutlets();
      }
    }
    this.publishTargetResolving = false;
  }

  async #loadUnusedDesign(designId: number): Promise<void> {
    await withPluginApi((api) =>
      previewDesign(api, designId, {
        drafts: this.wireframeDrafts,
        liveLayout: this.wireframeLiveLayout,
        publishTarget: this.wireframePublishTarget,
      })
    );
  }

  /**
   * Re-seeds the session drafts of outlets with no edits, so they pick up
   * layouts that loaded after the session began.
   */
  #reseedCleanOutlets(): void {
    for (const outletName of this.wireframeLayoutQuery.editableOutlets) {
      if (
        this.wireframeMutationEngine.isOutletDrafted(outletName) &&
        !this.wireframeMutationEngine.editedOutletNames().includes(outletName)
      ) {
        _clearLayoutLayer(outletName, LAYOUT_LAYERS.SESSION_DRAFT);
        this.wireframeMutationEngine.dropOutlet(outletName);
      }
    }
    this.rediscover();
  }
}
