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
  replaceEntryContainerArgs,
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
  @service blocks;
  @service currentUser;
  @service modal;
  @service siteSettings;
  @service wireframeArgEdit;
  @service wireframeBlockMutations;
  @service wireframeBlockReveal;
  @service wireframeClipboard;
  @service wireframeDrafts;
  @service wireframeDragOverlay;
  @service wireframeDragSession;
  @service wireframeEditEngine;
  @service wireframeEntryEdits;
  @service wireframeForceExpand;
  @service wireframeGridManipulator;
  @service wireframeImageUpload;
  @service wireframeInlineEdit;
  @service wireframeLayoutQuery;
  @service wireframePersistence;
  @service wireframeRevision;
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
   * the lookup settles (re-pointing `activeThemeId` to the companion if one is
   * found). The blocked callout and the indicator's blocked state read this so
   * they don't flash during the brief lookup — the callout appears only once it's
   * settled that there is genuinely no companion.
   *
   * @type {boolean}
   */
  @tracked publishTargetResolving = false;

  /**
   * Whether the drop-dispatch handler has been registered on
   * `wireframeDragOverlay`. Guards `enter()` so re-entry doesn't re-register.
   */
  #dropDispatchRegistered = false;

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

  /**
   * Tracks the mousedown target so the deselect handler can require
   * BOTH the down and up events to land outside the allowed scope.
   * Without this, dragging to select text inside an input (mousedown
   * on input, mouseup outside the input's bounds) would synthesise
   * a `click` on the common ancestor — often `<body>` — and trigger
   * an accidental deselect even though the user's intent was to
   * edit, not click elsewhere.
   *
   * @type {EventTarget|null}
   */
  #selectionMousedownTarget = null;
  #onCanvasMouseDown = (event) => {
    this.#selectionMousedownTarget = event.target;
  };

  /**
   * Document-level mouseup handler that clears the current selection
   * when BOTH the mousedown and mouseup landed outside the allowed
   * scope (block chrome, editor shell, the conditions floating
   * panel, or any Float-Kit portal — menus / modals / tooltips
   * mount their content at body level via portals, so they're
   * physically outside the shell even though they're conceptually
   * part of it). Block chromes already stop propagation on their
   * own click handler — we use mouseup rather than click here so
   * the input-text-selection case (described in
   * `#selectionMousedownTarget`) doesn't deselect.
   *
   * Bound once in `enter()` and removed in `exit()` so the editor
   * adds no global handler weight when inactive.
   *
   * @param {MouseEvent} event
   */
  #onCanvasMouseUp = (event) => {
    const downTarget = this.#selectionMousedownTarget;
    this.#selectionMousedownTarget = null;
    // Guard against a leaked listener firing after the owner is torn down: a
    // destroyed service throws when reading `selectedBlockKey` resolves the
    // selection injection on the dead owner. `isDestroyed`/`isDestroying` are
    // plain instance flags, so reading them never triggers a lookup.
    if (this.isDestroyed || this.isDestroying) {
      return;
    }
    if (!this.isActive || !this.selectedBlockKey) {
      return;
    }
    if (this.isInsideAllowedScope(downTarget)) {
      return;
    }
    if (this.isInsideAllowedScope(event.target)) {
      return;
    }
    this.selectBlock(null);
  };

  constructor() {
    super(...arguments);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    // The canvas selection listeners are normally removed in `exit()`, but a
    // session torn down without an explicit exit (e.g. the owner being
    // destroyed) would otherwise leak them at the document level. Removing them
    // here on teardown is idempotent and stops a leaked handler from firing
    // against this destroyed service. `removeEventListener` is a no-op when the
    // listener was never added or was already removed.
    document.removeEventListener("mousedown", this.#onCanvasMouseDown);
    document.removeEventListener("mouseup", this.#onCanvasMouseUp);
    this.wireframeBlockReveal.reset();
  }

  /**
   * Whether the current user is allowed to use the editor. Staff are always
   * allowed. Non-staff users must belong to at least one of the groups listed
   * in the `wireframe_allowed_groups` site setting. The plugin must also
   * be enabled via `wireframe_enabled`.
   *
   * @returns {boolean}
   */
  get canEdit() {
    if (!this.siteSettings.wireframe_enabled) {
      return false;
    }
    if (!this.currentUser) {
      return false;
    }
    if (this.currentUser.staff) {
      return true;
    }
    // Group-list site settings serialize as a pipe-delimited string of
    // group ids ("1|11|41"). Empty values produce empty strings, hence the
    // filter to drop them.
    const allowed = (this.siteSettings.wireframe_allowed_groups || "")
      .split("|")
      .filter(Boolean);
    if (allowed.length === 0) {
      return false;
    }
    const userGroupIds = (this.currentUser.groups || []).map((g) =>
      String(g.id)
    );
    return allowed.some((id) => userGroupIds.includes(String(id)));
  }

  /**
   * The names of every block outlet that's editable on the current page —
   * either one that already has a registered layout or one whose
   * `<BlockOutlet>` is mounted in the DOM with no layout yet.
   * Including the empty-mounted case makes "start a layout from
   * scratch" possible — the entry pill surfaces even when no code
   * path has called `api.renderBlocks(...)` for that outlet.
   *
   * Mounted outlets that aren't registered are silently ignored (they
   * can't have a layout, so they shouldn't appear in the editor).
   *
   * @returns {string[]}
   */
  get editableOutlets() {
    const registered = this.blocks.listOutlets();
    // Which outlets are actually on this page — the blocks service's
    // mounted-outlet registry, populated by each `<BlockOutlet>`'s lifecycle at
    // page render (no DOM scan, no enter-time race). An outlet is editable when
    // it has a layout OR is mounted here (so an empty outlet can be built from
    // scratch).
    const mounted = this.blocks.mountedOutletNames();
    return registered.filter(
      (name) => this.blocks.hasLayout(name) || mounted.has(name)
    );
  }

  /**
   * Theme facade — delegates to `wireframeTheme`. The id of the theme this
   * session is bound to (set on enter, repointed to a companion, cleared on
   * exit). Null while no session is active.
   *
   * @returns {number|null}
   */
  get activeThemeId() {
    return this.wireframeTheme.activeThemeId;
  }

  /**
   * Theme facade — delegates to `wireframeTheme`. The fallback publish target
   * for an outlet nothing owns yet.
   *
   * @returns {number|null}
   */
  get defaultThemeId() {
    return this.wireframeTheme.defaultThemeId;
  }

  /**
   * Theme facade — delegates to `wireframeTheme`. Whether the bound theme is a
   * core "system" theme (negative id) that can't be published to directly.
   *
   * @returns {boolean}
   */
  get activeThemeIsSystem() {
    return this.wireframeTheme.activeThemeIsSystem;
  }

  /**
   * The resolved-layout revision beacon. Bumped on every structural mutation
   * (and on a simulation toggle) so consumers reading it re-run on any change.
   * Delegates to the revision service; re-exposed here so the components and
   * internal getters that read `structuralVersion` need not inject it directly.
   *
   * @returns {number}
   */
  get structuralVersion() {
    return this.wireframeRevision.version;
  }

  /**
   * Whether an editor session is currently open. Delegates to the session
   * signal service; re-exposed here (with a setter) so the many components,
   * templates, and internal readers that use `isActive` — plus tests that flip
   * it to fake an active session — stay unchanged without injecting the service.
   *
   * @returns {boolean}
   */
  get isActive() {
    return this.wireframeSession.active;
  }

  set isActive(value) {
    if (value) {
      this.wireframeSession.activate();
    } else {
      this.wireframeSession.deactivate();
    }
  }

  /**
   * The outlet/layout query service (entry/outlet lookups, block metadata,
   * outlet state, grid/composite predicates, outlet-root identity). Re-exposed
   * here so internal `this.layoutQuery.X` and external `wireframe.layoutQuery.X`
   * keep working without injecting the service directly.
   *
   * @returns {import("./wireframe-layout-query").default}
   */
  get layoutQuery() {
    return this.wireframeLayoutQuery;
  }

  /**
   * The inline-text-edit session service. Re-exposed here so internal
   * `this.inlineEdit.X` and external `wireframe.inlineEdit.X` consumers keep
   * working without injecting the service directly.
   *
   * @returns {import("./wireframe-inline-edit").default}
   */
  get inlineEdit() {
    return this.wireframeInlineEdit;
  }

  /**
   * Contextual toolbar field-editor slot. Re-exposed here (read + write) so the
   * inline-edit controller and the block toolbar keep using
   * `wireframe.fieldEditor` while the state lives on the inline-edit service.
   *
   * @returns {Object|null}
   */
  get fieldEditor() {
    return this.wireframeInlineEdit.fieldEditor;
  }

  /** @param {Object|null} descriptor */
  set fieldEditor(descriptor) {
    this.wireframeInlineEdit.setFieldEditor(descriptor);
  }

  /* Selection facade — the block-selection concern lives on
   * `wireframeSelection`. These delegators keep every external consumer
   * (panels, chrome, toolbar) and every kernel-internal reader unchanged
   * while the state and commands moved out. The raw `selectedKeys` set is
   * deliberately NOT re-exposed; consumers read `selectionCount` /
   * `selectedKeysSnapshot` / `isBlockSelected` instead. */

  /** @returns {string|null} */
  get selectedBlockKey() {
    return this.wireframeSelection.selectedBlockKey;
  }

  /** @returns {Object|null} */
  get selectedBlockData() {
    return this.wireframeSelection.selectedBlockData;
  }

  /** @returns {{failureType: string, failureReason: string}|null} */
  get selectedBlockFailure() {
    return this.wireframeSelection.selectedBlockFailure;
  }

  /** @returns {Object<string, Array<Object>>} */
  get selectedBlockFieldErrors() {
    return this.wireframeSelection.selectedBlockFieldErrors;
  }

  /** @returns {Array<Object>} */
  get selectedBlockNonFieldErrors() {
    return this.wireframeSelection.selectedBlockNonFieldErrors;
  }

  /** @returns {boolean} */
  get selectedBlockHasErrors() {
    return this.wireframeSelection.selectedBlockHasErrors;
  }

  /** @returns {boolean} */
  get canMoveSelectedUp() {
    return this.wireframeSelection.canMoveSelectedUp;
  }

  /** @returns {boolean} */
  get canMoveSelectedDown() {
    return this.wireframeSelection.canMoveSelectedDown;
  }

  /** @returns {Array<Object>} */
  get selectedBlockAncestry() {
    return this.wireframeSelection.selectedBlockAncestry;
  }

  /** @returns {Object|null} */
  get selectedBlockRawEntry() {
    return this.wireframeSelection.selectedBlockRawEntry;
  }

  /** @returns {Array|Object|null} */
  get selectedBlockConditions() {
    return this.wireframeSelection.selectedBlockConditions;
  }

  /** @returns {boolean} */
  get hasMultiSelection() {
    return this.wireframeSelection.hasMultiSelection;
  }

  /** @returns {number} */
  get selectionCount() {
    return this.wireframeSelection.selectionCount;
  }

  /* Edit-engine facade — the mutation / undo / dirty-tracking concern lives on
   * `wireframeEditEngine`. These delegators keep every external consumer and
   * every kernel-internal caller (the ~30 `recordStructural` sites, the
   * grid-manipulator `svc.` and inline-editor `this.service.` callers, the
   * toolbar's undo/redo actions) unchanged while the state and commands moved
   * out. No raw state (the dirty sets, the undo/redo stacks, the snapshot map)
   * is re-exposed; consumers read through the engine's query methods. */

  /** @returns {boolean} */
  get canUndo() {
    return this.wireframeEditEngine.canUndo;
  }

  /** @returns {boolean} */
  get canRedo() {
    return this.wireframeEditEngine.canRedo;
  }

  /** @returns {boolean} */
  get isDirty() {
    return this.wireframeEditEngine.isDirty;
  }

  /** @returns {number} The number of entries on the undo stack. */
  get undoDepth() {
    return this.wireframeEditEngine.undoDepth;
  }

  /** @returns {number} The number of entries on the redo stack. */
  get redoDepth() {
    return this.wireframeEditEngine.redoDepth;
  }

  /**
   * The set of outlet names the editor has materialised a draft layer for, as a
   * frozen array. Re-exposed so the outline panel can read it through the kernel
   * without injecting the engine directly.
   *
   * @returns {ReadonlyArray<string>}
   */
  draftedOutletNames() {
    return this.wireframeEditEngine.draftedOutletNames();
  }

  /**
   * Whether an outlet has any unsaved edit — structural or arg-level. Facade
   * over the engine so external readers go through the kernel.
   *
   * @param {string} outletName
   * @returns {boolean}
   */
  isOutletEdited(outletName) {
    return this.wireframeEditEngine.isOutletEdited(outletName);
  }

  /**
   * Re-publishes a draft layout layer with structural changes applied and marks
   * the outlet edited. Facade over the engine so the many structural-mutation
   * call sites (here, the grid manipulator, the inline editors) are unchanged.
   *
   * @param {string} outletName
   * @param {Array<Object>} newLayout
   */
  publishStructuralChange(outletName, newLayout) {
    return this.wireframeEditEngine.publishStructuralChange(
      outletName,
      newLayout
    );
  }

  /**
   * Wraps a structural mutation in undo/redo + dirty bookkeeping. Facade over
   * the engine; the closures callers pass reach `publishStructuralChange` back
   * through this same kernel facade, resolving to the one engine instance.
   *
   * @template T
   * @param {string[]} outletNames
   * @param {() => T} mutateFn
   * @returns {T}
   */
  recordStructural(outletNames, mutateFn) {
    return this.wireframeEditEngine.recordStructural(outletNames, mutateFn);
  }

  /**
   * Writes a single arg value immediately (not keystroke-debounced) through the
   * undo-aware write path. Facade over the engine.
   *
   * @param {string} blockKey
   * @param {string} argName
   * @param {*} value
   */
  setArg(blockKey, argName, value) {
    return this.wireframeEditEngine.setArg(blockKey, argName, value);
  }

  /**
   * Writes a `Map<argName, value>` of arg values into `entry.args`. Facade over
   * the engine.
   *
   * @param {Object} entry
   * @param {Map<string, *>} args
   */
  writeArgs(entry, args) {
    return this.wireframeEditEngine.writeArgs(entry, args);
  }

  /**
   * Captures an entry's pre-edit args the first time it's about to be mutated.
   * Facade over the engine.
   *
   * @param {Object} entry
   * @param {Map<string, *>} prev
   */
  captureInitialSnapshot(entry, prev) {
    return this.wireframeEditEngine.captureInitialSnapshot(entry, prev);
  }

  /**
   * Reverts the most recent mutation. Facade over the engine — returns the
   * Promise so callers awaiting the result aren't left hanging.
   *
   * @returns {Promise<boolean>}
   */
  @action
  undo() {
    return this.wireframeEditEngine.undo();
  }

  /**
   * Re-applies the most recently undone mutation. Facade over the engine.
   *
   * @returns {Promise<boolean>}
   */
  @action
  redo() {
    return this.wireframeEditEngine.redo();
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
    return this.isDirty || this.hasUnsavedDraftEdits;
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
      this.layoutQuery.readResolvedLayout(outletName)
    );
    const baseline = this.#persistedDraftLayouts.has(outletName)
      ? this.#persistedDraftLayouts.get(outletName)
      : this.#serializeBaseline(
          this.layoutQuery.readResolvedLayout(outletName, {
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
    if (!this.canEdit) {
      return;
    }
    this.wireframeSession.activate();
    this.wireframeImageUpload.clearPending();
    // Hand the overlay our drop dispatcher so it never reaches up into this
    // service. Synchronous + returns a boolean (the `completeExternalImageDrop`
    // contract). Registered once; the guard keeps re-entry from re-wrapping it.
    if (!this.#dropDispatchRegistered) {
      this.wireframeDragOverlay.registerDispatcher((payload) =>
        this.runDropDispatch(payload)
      );
      this.#dropDispatchRegistered = true;
    }
    // New session generation: invalidates any draft hydration still in flight
    // from a previous enter/exit so it can't write into this session.
    const generation = ++this.#enterGeneration;
    this.wireframeTheme.setActiveTheme(themeId);
    // A theme that can't be published to directly may have a companion to retarget
    // to; suppress the blocked callout until the after-render lookup settles.
    this.publishTargetResolving = this.activeThemeTarget?.publishable === false;
    document.body.classList.add("wireframe-active");
    document.addEventListener("mousedown", this.#onCanvasMouseDown);
    document.addEventListener("mouseup", this.#onCanvasMouseUp);
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
    if (!this.isActive) {
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
    if (!this.isActive) {
      return;
    }
    const materialized = this.#materializeAllDrafts();
    // Only refetch persisted drafts when a fresh outlet was actually seeded —
    // navigating between pages that share outlets shouldn't trigger a fetch.
    if (materialized > 0) {
      this.#hydrateDrafts(this.#enterGeneration);
    }
  }

  /**
   * Ensures a session-draft layer exists for `outletName` — delegates to the
   * edit-engine, which owns the draft + baseline bookkeeping. Kept as a thin
   * facade so the kernel's structural-mutation callers stay unchanged.
   *
   * @param {string} outletName
   * @returns {Array<Object>} the layout array (existing or freshly minted).
   */
  ensureDraft(outletName) {
    return this.wireframeEditEngine.ensureDraft(outletName);
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
    this.layoutQuery.clearOutletRoots();
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
    document.removeEventListener("mousedown", this.#onCanvasMouseDown);
    document.removeEventListener("mouseup", this.#onCanvasMouseUp);
    this.#selectionMousedownTarget = null;
  }

  /**
   * Block-mutations facade — delegates to `wireframeBlockMutations`. Moves the
   * selected block one step earlier in its parent (visually up).
   *
   * @param {string} blockKey
   * @returns {boolean}
   */
  @action
  moveBlockUp(blockKey) {
    return this.wireframeBlockMutations.moveBlockUp(blockKey);
  }

  /**
   * Block-mutations facade — delegates to `wireframeBlockMutations`. Moves the
   * selected block one step later in its parent (visually down).
   *
   * @param {string} blockKey
   * @returns {boolean}
   */
  @action
  moveBlockDown(blockKey) {
    return this.wireframeBlockMutations.moveBlockDown(blockKey);
  }

  /**
   * Block-mutations facade — delegates to `wireframeBlockMutations`. Inserts
   * `count` clones of the block immediately after it (one undo step).
   *
   * @param {string} blockKey
   * @param {number} [count=1]
   * @returns {boolean}
   */
  @action
  duplicateBlock(blockKey, count = 1) {
    return this.wireframeBlockMutations.duplicateBlock(blockKey, count);
  }

  /**
   * Block-mutations facade — delegates to `wireframeBlockMutations`. Removes a
   * single block (no-op on the outlet root).
   *
   * @param {string} blockKey
   * @returns {boolean}
   */
  @action
  removeBlock(blockKey) {
    return this.wireframeBlockMutations.removeBlock(blockKey);
  }

  /**
   * Block-mutations facade — delegates to `wireframeBlockMutations`. Removes
   * several blocks in one undo step (outlet roots skipped).
   *
   * @param {Array<string>} keys
   * @returns {boolean}
   */
  @action
  removeBlocks(keys) {
    return this.wireframeBlockMutations.removeBlocks(keys);
  }

  /**
   * Entry-edits facade — delegates to `wireframeEntryEdits`. Replaces the
   * `conditions` tree on the currently-selected block (used by the inspector's
   * condition builder; `null` clears all conditions).
   *
   * @param {Array|Object|null} newConditions
   * @returns {boolean}
   */
  @action
  updateSelectedConditions(newConditions) {
    return this.wireframeEntryEdits.updateSelectedConditions(newConditions);
  }

  /**
   * Entry-edits facade — delegates to `wireframeEntryEdits`. Sets/clears the
   * selected entry's `id`, returning `{ ok, error }` for inline validation.
   *
   * @param {string|null} nextId
   * @returns {{ok: boolean, error: string|null}}
   */
  @action
  updateSelectedEntryId(nextId) {
    return this.wireframeEntryEdits.updateSelectedEntryId(nextId);
  }

  /**
   * Entry-edits facade — delegates to `wireframeEntryEdits`. Replaces the
   * selected entry with a parsed entry object (inspector Raw JSON tab).
   *
   * @param {Object} parsed
   * @returns {boolean}
   */
  @action
  replaceSelectedEntryRaw(parsed) {
    return this.wireframeEntryEdits.replaceSelectedEntryRaw(parsed);
  }

  /**
   * Captures the currently-selected block onto the clipboard AND removes it from
   * the canvas. Cut is a composition of two concerns: the clipboard stashes the
   * entry (mode `"cut"`), and the kernel performs the structural removal, since
   * `removeBlock` carries kernel-owned nuance (outlet-root guard, entry-removal
   * helper, selection-clear). The key is captured before stashing — the stash
   * doesn't change selection. If the stash fails (nothing selected / not
   * locatable) the removal is skipped.
   *
   * @returns {boolean} true on success, false when no block is selected
   */
  @action
  cutSelected() {
    const key = this.selectedBlockKey;
    return this.wireframeClipboard.cutSelected() && this.removeBlock(key);
  }

  @action
  toggle() {
    if (this.isActive) {
      this.exit();
    } else {
      this.enter();
    }
  }

  /**
   * Selection facade — delegates to `wireframeSelection`. The kernel's
   * cross-concern effects (flush pending args, commit an in-flight in-session
   * edit, reveal the selection into view) run as before/after hooks registered
   * in `enter()`.
   *
   * @param {Object|null} data - `{ key, ... }` (rest hydrated from the layout).
   * @param {{preserveMultiSelection?: boolean}} [options]
   */
  selectBlock(data, options) {
    return this.wireframeSelection.selectBlock(data, options);
  }

  /**
   * Called by a block's editor chrome from its `didInsert` once its element
   * exists. Delegates to the reveal/flash leaf, which runs any reveal or flash
   * that was deferred because the element wasn't in the DOM when the block was
   * selected. See `../services/wireframe-block-reveal.js`.
   *
   * @param {string} blockKey - The mounting block's composite key.
   * @param {HTMLElement} element - The block's chrome element.
   */
  notifyChromeInserted(blockKey, element) {
    this.wireframeBlockReveal.notifyChromeInserted(blockKey, element);
  }

  /**
   * Briefly flashes the rendered element for the given block key to draw the
   * eye to it — used when selection originates somewhere other than a direct
   * click on the block (outline selection, insert auto-select). Delegates to
   * the reveal/flash leaf. See `../services/wireframe-block-reveal.js`.
   *
   * @param {string|null} blockKey - The composite key of the block to flash.
   */
  flashBlock(blockKey) {
    this.wireframeBlockReveal.flash(blockKey);
  }

  /**
   * Selection facade — delegates to `wireframeSelection`. Kept as `@action`
   * because the outline binds it as a template subexpression
   * (`(this.wireframe.isBlockSelected row.blockKey)`); without it Glimmer
   * extracts the bare function and calls it without the correct `this`.
   *
   * @param {string|null} key - The composite block key (`${name}:${__stableKey}`).
   * @returns {boolean}
   */
  @action
  isBlockSelected(key) {
    return this.wireframeSelection.isBlockSelected(key);
  }

  /**
   * Selection facade — delegates to `wireframeSelection`. A frozen, read-only
   * copy of the selected keys for consumers that need the full set (e.g.
   * multi-delete).
   *
   * @returns {ReadonlyArray<string>}
   */
  selectedKeysSnapshot() {
    return this.wireframeSelection.selectedKeysSnapshot();
  }

  /**
   * Selection facade — delegates to `wireframeSelection`.
   *
   * @param {Object} data - `{ key, ... }` for the toggled block.
   */
  toggleBlockSelection(data) {
    return this.wireframeSelection.toggleBlockSelection(data);
  }

  /**
   * Selection facade — delegates to `wireframeSelection`.
   *
   * @param {Array<string>} keys - The block keys to select.
   * @param {Object} anchorData - `{ key, ... }` for the anchor (clicked) block.
   */
  setSelectionRange(keys, anchorData) {
    return this.wireframeSelection.setSelectionRange(keys, anchorData);
  }

  /**
   * Selection facade — delegates to `wireframeSelection`.
   *
   * @param {string} outletName
   */
  selectOutlet(outletName) {
    return this.wireframeSelection.selectOutlet(outletName);
  }

  /**
   * Image-upload facade — delegates to `wireframeImageUpload`. Uploads a File
   * and writes the result into a block's image arg.
   *
   * @param {File|Blob} file
   * @param {{blockKey: string, argName: string}} options
   * @returns {Promise<{url: string, width?: number, height?: number}|null>}
   */
  uploadImageForArg(file, options) {
    return this.wireframeImageUpload.uploadImageForArg(file, options);
  }

  /**
   * Image-upload facade — delegates to `wireframeImageUpload`. Completes an OS
   * image-file drop onto an empty slot (dispatch the previewed insert, stage the
   * file for the new block).
   *
   * @param {File} file
   * @returns {boolean}
   */
  completeExternalImageDrop(file) {
    return this.wireframeImageUpload.completeExternalImageDrop(file);
  }

  /**
   * Image-upload facade — delegates to `wireframeImageUpload`. Stages a dropped
   * file against a block's image arg for its overlay to upload on mount.
   *
   * @param {string} blockKey
   * @param {string} argName
   * @param {File} file
   */
  stagePendingDropFile(blockKey, argName, file) {
    return this.wireframeImageUpload.stagePendingDropFile(
      blockKey,
      argName,
      file
    );
  }

  /**
   * Image-upload facade — delegates to `wireframeImageUpload`. Returns and
   * removes the file staged for a block's image arg.
   *
   * @param {string} blockKey
   * @param {string} argName
   * @returns {File|null}
   */
  consumePendingDropFile(blockKey, argName) {
    return this.wireframeImageUpload.consumePendingDropFile(blockKey, argName);
  }

  /**
   * Image-upload facade — delegates to `wireframeImageUpload`. Writes a single
   * image arg value through the engine's write-path.
   *
   * @param {string} blockKey
   * @param {string} argName
   * @param {*} value
   */
  setImageArg(blockKey, argName, value) {
    return this.wireframeImageUpload.setImageArg(blockKey, argName, value);
  }

  /**
   * Image-upload facade — delegates to `wireframeImageUpload`. Records the most
   * recently interacted-with image arg so a subsequent paste routes to it.
   *
   * @param {string} argName
   */
  markImageArgTouched(argName) {
    return this.wireframeImageUpload.markImageArgTouched(argName);
  }

  /**
   * Updates one field inside a `containerArgs` namespace bag of the selected
   * entry (e.g. `containerArgs.grid.column`). Placement edits are rarer than
   * typography edits, so we route directly through `replaceEntryContainerArgs`
   * (structural commit) rather than the keystroke-debounced arg-edit pipeline
   * (`wireframeArgEdit`) used for `args`.
   *
   * @param {string} namespace - The childArgs namespace key (e.g. "grid").
   * @param {string} name - The field name inside the namespace.
   * @param {*} value
   * @returns {boolean}
   */
  @action
  updateSelectedContainerArg(namespace, name, value) {
    if (!this.selectedBlockKey || !namespace || !name) {
      return false;
    }
    const located = this.layoutQuery.findEntryAndOutletSync(
      this.selectedBlockKey
    );
    if (!located) {
      return false;
    }
    return this.recordStructural([located.outletName], () => {
      const layout = this.layoutQuery.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const result = replaceEntryContainerArgs(
        layout,
        this.selectedBlockKey,
        namespace,
        (current) => ({ ...current, [name]: value })
      );
      if (!result.changed) {
        return false;
      }
      this.publishStructuralChange(located.outletName, result.layout);
      return true;
    });
  }

  /**
   * Re-resolves the given block key against the current layout and rebinds
   * `selectedBlockKey` / `selectedBlockData`. If the key no longer exists,
   * clears the selection. Used after structural undo / redo to follow the
   * selection across layout snapshots.
   *
   * @param {string|null} blockKey
   */
  restoreSelection(blockKey) {
    return this.wireframeSelection.restoreSelection(blockKey);
  }

  /**
   * In-memory rollback of every touched outlet to its pristine pre-edit state,
   * then clears the undo/redo history. Facade over the engine — the toolbar's
   * Reset action calls it through the kernel.
   *
   * @returns {Promise<boolean>}
   */
  @action
  resetAll() {
    return this.wireframeEditEngine.resetAll();
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
      this.outletOwner(outletName).themeId ?? this.defaultThemeId,
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
    if (!this.isDirty) {
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
    const owner = this.outletOwner(outletName);
    if (
      this.layoutQuery.outletState(outletName) !== OUTLET_STATE.PUBLISHED ||
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
    const result = await this.wireframePersistence.publish(this.activeThemeId);
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
      this.activeThemeId
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
    await this.wireframeDrafts.saveDraftOutlet(this.activeThemeId, outletName);
    // The persisted draft now matches the canvas — advance the baseline so the
    // outlet reads as having no unsaved draft edits until the next change.
    this.#persistedDraftLayouts.set(
      outletName,
      this.#serializeBaseline(this.layoutQuery.readResolvedLayout(outletName))
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
    const themeId = this.outletOwner(outletName).themeId ?? this.defaultThemeId;
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
        this.activeThemeId
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
          this.activeThemeId
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

  /**
   * Theme facade — delegates to `wireframeTheme`. Hard-navigates the editor onto
   * a different theme (full reload with `?wf_theme=<id>`).
   *
   * @param {number} themeId
   */
  navigateToEditTheme(themeId) {
    return this.wireframeTheme.navigateToEditTheme(themeId);
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
   * Theme facade — delegates to `wireframeTheme`. The theme that owns an outlet
   * (where Publish writes its live field) plus the badge/gate metadata.
   *
   * @param {string} outletName
   * @returns {{themeId: (number|null), themeName: (string|null), isGit: boolean, stackIndex: (number|undefined), layer: string}}
   */
  outletOwner(outletName) {
    return this.wireframeTheme.outletOwner(outletName);
  }

  /**
   * Theme facade — delegates to `wireframeTheme`. The edited outlets grouped by
   * owning theme — the publish plan.
   *
   * @returns {Array<{themeId: (number|null), themeName: (string|null), isGit: boolean, isSystem: boolean, publishable: boolean, outlets: Array<string>}>}
   */
  get publishTargets() {
    return this.wireframeTheme.publishTargets;
  }

  /**
   * Theme facade — delegates to `wireframeTheme`. The theme this session would
   * publish to before anything is edited.
   *
   * @returns {{themeId: number, themeName: (string|null), isGit: boolean, isSystem: boolean, publishable: boolean}|null}
   */
  get activeThemeTarget() {
    return this.wireframeTheme.activeThemeTarget;
  }

  /**
   * Whether an outlet has unsaved in-session edits. Reads the tracked edit
   * bookkeeping directly so a template binding (the EDITING pill) re-runs as
   * edits come and go.
   *
   * @param {string} outletName
   * @returns {boolean}
   */
  isOutletEditing(outletName) {
    return this.wireframeEditEngine.isOutletEdited(outletName);
  }

  /**
   * Records the start of a drag. The `editor-draggable` modifier feeds this
   * via its `onDragStart` callback. The body class lights up the canvas's
   * drop-zone CSS (zones are `display: none` until the body has the class).
   *
   * @param {{blockKey: string, outletName: string}} payload
   */
  @action
  startDrag({ blockKey, outletName }) {
    this.wireframeDragOverlay.clear();
    this.wireframeDragSession.beginBlock({ blockKey, outletName });
    document.body.classList.add("wireframe-dragging");
  }

  /**
   * Records the start of a palette-driven drag. Mirrors `startDrag`
   * but with the `wf-palette-block` type so dragover-time consumers
   * can pick the right label / dispatch action. Called from
   * `PaletteEntry`'s `onDragStart`.
   *
   * @param {{blockName: string, defaultArgs: Object}} payload
   */
  @action
  startPaletteDrag({ blockName, defaultArgs }) {
    this.wireframeDragOverlay.clear();
    this.wireframeDragSession.beginPalette({ blockName, defaultArgs });
    document.body.classList.add("wireframe-dragging");
  }

  /**
   * Resets per-drag state at the end of an element drag (drop OR cancellation —
   * PDND's `draggable.onDrop` fires for both). Wired as the source modifier's
   * `onDrop` consumer callback, which the modifier defers via `queueMicrotask`
   * until after PDND's full dispatch chain has fired — so a drop handler has
   * already consumed the overlay via `wireframeDragOverlay.dispatch()` before
   * this final cleanup runs.
   */
  @action
  endDrag() {
    this.wireframeDragSession.clear();
    this.wireframeDragOverlay.clear();
    document.body.classList.remove("wireframe-dragging");
  }

  /**
   * Executes a drop dispatch payload by action name. The single chokepoint
   * `WireframeDragOverlay` holds the payload across the drag and calls this at
   * drop time; the action methods it names (`insertBlock`, `applyGridDrop`,
   * `placeBlockInCell`, …) live on this service.
   *
   * @param {{action: string, args: Object}} payload
   * @returns {boolean} `true` when the named action ran.
   */
  runDropDispatch({ action: actionName, args }) {
    const method = this[actionName];
    if (typeof method !== "function") {
      return false;
    }
    method.call(this, args);
    return true;
  }

  /**
   * Block-mutations facade — delegates to `wireframeBlockMutations`. Moves an
   * entry to a new position / outlet (drag, outline reorder, move buttons).
   *
   * @param {{sourceKey: string, targetKey: string|null, position: "before"|"after"|"inside", targetOutletName: string}} args
   * @returns {boolean}
   */
  @action
  moveBlock(args) {
    return this.wireframeBlockMutations.moveBlock(args);
  }

  /**
   * Block-mutations facade — delegates to `wireframeBlockMutations`. Inserts a
   * freshly-synthesised block at the target position (palette drop, add).
   *
   * @param {{blockName: string, defaultArgs?: Object, targetKey: string|null, position: "before"|"after"|"inside", targetOutletName: string}} args
   * @returns {boolean}
   */
  @action
  insertBlock(args) {
    return this.wireframeBlockMutations.insertBlock(args);
  }

  /**
   * Block-mutations facade — delegates to `wireframeBlockMutations`. Appends a
   * fresh child of the container's implicit-child kind and selects it.
   *
   * @param {string} containerKey
   * @returns {boolean}
   */
  appendImplicitChild(containerKey) {
    return this.wireframeBlockMutations.appendImplicitChild(containerKey);
  }

  /**
   * The dispatch entry for every grid drop. Drop surfaces (the grid overlay,
   * the container drop target) hand a request that DESCRIBES the drop — the
   * target grid, the gesture, and the source — without choosing an action.
   * This delegates to the grid manipulator, which routes the request through
   * `decideGridDrop` and into the matching executor. Wired into the
   * `{action, args}` drop channel as the single grid action, so no drop
   * surface can place into a grid without the decider.
   *
   * @param {Object} request - See the grid-manipulator service's `drop`.
   * @returns {boolean}
   */
  @action
  applyGridDrop(request) {
    return this.wireframeGridManipulator.drop(request);
  }

  /**
   * Dispatch shim for moving a canvas block onto an empty merged cell — the
   * collapsed-grid drop channel calls this by name. The logic lives in the
   * grid manipulator (`moveIntoCell`).
   *
   * @param {{sourceKey: string, cellKey: string}} args
   * @returns {boolean}
   */
  @action
  moveBlockIntoCell(args) {
    return this.wireframeGridManipulator.moveIntoCell(args);
  }

  /**
   * Dispatch shim for replacing an empty merged cell with a fresh block — the
   * collapsed-grid drop channel and the empty-cell picker call this by name.
   * The logic lives in the grid manipulator (`placeInCell`).
   *
   * @param {{cellKey: string, blockName: string, defaultArgs?: Object}} args
   * @returns {boolean}
   */
  @action
  placeBlockInCell(args) {
    return this.wireframeGridManipulator.placeInCell(args);
  }

  /**
   * The lock declaration for the currently-selected part, or null when the
   * selection isn't a part. `true` means the whole part is locked (no in-place
   * arg overrides); a string array lists the specific arg names that can't be
   * overridden in place. Drives the inspector's disabling of locked fields.
   *
   * @returns {true|string[]|null}
   */
  partLockForSelection() {
    return this.wireframeSelection.partLockForSelection();
  }

  /**
   * Entry-edits facade — delegates to `wireframeEntryEdits`. Detaches the
   * selected composite into a plain container (materialises its parts, drops the
   * override map).
   *
   * @returns {boolean}
   */
  @action
  detachSelectedComposite() {
    return this.wireframeEntryEdits.detachSelectedComposite();
  }

  isInsideAllowedScope(target) {
    if (!(target instanceof Element)) {
      return false;
    }
    return Boolean(
      target.closest(".wireframe-block-chrome") ||
      target.closest(".wireframe-shell") ||
      target.closest(".wireframe-conditions-floating-panel") ||
      // Float-Kit portals (menus / modals / tooltips) mount at body
      // level, outside the shell. They're conceptually part of the
      // editor surface (an icon picker, a colour swatch dropdown,
      // a hover tooltip) so clicks inside them must NOT deselect.
      target.closest(".fk-d-menu") ||
      target.closest(".fk-d-menu-modal") ||
      target.closest(".fk-d-tooltip__content")
    );
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
    for (const outletName of this.editableOutlets) {
      if (this.wireframeEditEngine.isOutletDrafted(outletName)) {
        continue;
      }
      // A LOCKED outlet is owned by a non-overridable programmatic layout: it
      // stays read-only, so never seed a draft for it (the outline still lists
      // it via `editableOutlets`, but the chrome marks it non-editable).
      if (this.layoutQuery.outletState(outletName) === OUTLET_STATE.LOCKED) {
        continue;
      }
      const layout = this.layoutQuery.readResolvedLayout(outletName);
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
        (ref) => this.layoutQuery.lookupBlockMetadata(ref)
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
      this.layoutQuery.recordOutletRoot(outletName);
      // Rollback target for `resetAll()`. Cloned from the just-published
      // draft (not the pre-wrap layout) so it carries the normalised shape
      // and the minted root `__stableKey` — that keeps the recorded root key
      // valid after a reset re-publishes this snapshot. A separate clone so
      // in-place arg mutations on the draft never leak into the snapshot.
      this.wireframeEditEngine.captureBaseline(
        outletName,
        cloneLayoutForDraft(
          this.layoutQuery.readResolvedLayout(outletName) ?? []
        )
      );
    }
    return materialized;
  }

  /**
   * When the bound theme can't be published to directly, look up its companion
   * component and re-point `activeThemeId` to it — so the editor targets the
   * publishable companion the user already set up instead of the unpublishable
   * parent. A no-op (and clears the resolving flag) when the theme is already
   * publishable or has no companion. Generation-guarded so a late lookup never
   * writes into a new session.
   *
   * @param {number} generation
   * @returns {Promise<void>}
   */
  async #resolveCompanionTarget(generation) {
    const target = this.activeThemeTarget;
    if (!target || target.publishable) {
      this.publishTargetResolving = false;
      return;
    }
    const companionId = await this.wireframeDrafts.companionId(
      this.activeThemeId
    );
    if (generation !== this.#enterGeneration || !this.isActive) {
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
    if (generation !== this.#enterGeneration || !this.isActive) {
      return;
    }
    const themeIds = [
      ...new Set(
        this.editableOutlets
          .map((name) => this.outletOwner(name).themeId)
          .filter((id) => id != null)
      ),
    ];
    const drafts = await this.wireframeDrafts.fetchDrafts(themeIds);
    // Bail if the user exited or re-entered while the fetch was in flight.
    if (generation !== this.#enterGeneration || !this.isActive) {
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
      (ref) => this.layoutQuery.lookupBlockMetadata(ref)
    );
    _setLayoutLayer(
      outlet,
      LAYOUT_LAYERS.SESSION_DRAFT,
      draftLayout,
      getOwner(this),
      { permissive: true }
    );
    this.layoutQuery.recordOutletRoot(outlet);
    this.wireframeEditEngine.markOutletStructurallyEdited(outlet);
    // Record what the saved draft holds, so an edit that returns the canvas to the
    // published layout is still recognized as differing from the persisted draft.
    this.#persistedDraftLayouts.set(
      outlet,
      this.#serializeBaseline(this.layoutQuery.readResolvedLayout(outlet))
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
      this.inlineEdit.blockKey == null
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

  /**
   * Block-mutations facade — delegates to `wireframeBlockMutations`. Selects a
   * freshly inserted entry (by its assigned stable key) and flashes it.
   *
   * @param {Object} entry
   */
  selectInsertedEntry(entry) {
    return this.wireframeBlockMutations.selectInsertedEntry(entry);
  }

  /**
   * Block-mutations facade — delegates to `wireframeBlockMutations`. Moves an
   * entry across outlets (or between grids in one outlet), wrapping / unwrapping
   * for the destination and claiming a grid cell on a grid landing.
   *
   * @param {{sourceOutletName: string, targetOutletName: string, sourceKey: string, targetKey: string|null, position: "before"|"after"|"inside", autoPosition?: boolean}} args
   * @returns {boolean}
   */
  moveAcrossOutlets(args) {
    return this.wireframeBlockMutations.moveAcrossOutlets(args);
  }
}
