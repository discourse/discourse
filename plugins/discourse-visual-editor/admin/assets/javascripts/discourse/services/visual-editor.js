// @ts-check
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import {
  trackedArray,
  trackedMap,
  trackedSet,
} from "@ember/reactive/collections";
import Service, { service } from "@ember/service";
import {
  _clearLayoutLayer,
  _getOutletLayouts,
  _setLayoutLayer,
  LAYOUT_LAYERS,
} from "discourse/blocks/block-outlet";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import { VALID_BLOCK_ID_PATTERN } from "discourse/lib/blocks/-internals/patterns";
import discourseDebounce from "discourse/lib/debounce";
import PreloadStore from "discourse/lib/preload-store";
// Absolute addon path: `grid-math` is in the universal bundle (its
// `parsePlacement` is called by the live-page `ve-layout.gjs`); this
// service is admin-only. Cross-bundle imports use absolute paths.
import {
  computeShiftPlan,
  parsePlacement,
  placementsOverlap,
} from "discourse/plugins/discourse-visual-editor/discourse/lib/grid-math";
import { resolveTemplateLayout } from "../lib/grid-templates";
import {
  cloneEntryForPaste,
  cloneLayoutForDraft,
  entryKey,
  findAncestryPath,
  findEntry,
  findEntrySiblings,
  insertEntryAt,
  moveEntry,
  removeEntry,
  replaceEntryConditions,
  replaceEntryContainerArgs,
  replaceEntryId,
  replaceEntryInPlace,
  serializeEntryForSave,
} from "../lib/mutate-layout";
import { inferSchemaFromValues } from "../lib/schema-to-fields";
import { mountedOutletNames } from "../lib/walk-layout";

const FLUSH_DELAY_MS = 200;

/**
 * Phase 1 + 2 + 3 editor service. Holds the editor's session state and
 * mediates the in-memory mutation pipeline.
 *
 * Reactivity contract: every `@tracked` field on this service is read by the
 * panels and the canvas chrome. Mutating one re-renders the relevant pieces
 * via Glimmer's tracking system without manual notification.
 *
 * Mutation pipeline: at `enter()`, the editor deep-clones every outlet's
 * resolved layout and publishes those clones as the `session-draft` layer
 * (highest precedence in the block resolution chain). Edits during the
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
 * (Phase 3d) publishes the saved layout to the `theme` layer silently —
 * the session-draft is still resolved at that point, so the page doesn't
 * re-render at save time.
 */
export default class VisualEditorService extends Service {
  @service blocks;
  @service currentUser;
  @service site;
  @service siteSettings;

  @tracked isActive = false;
  @tracked selectedBlockKey = null;

  /**
   * The id of the theme this editor session is bound to. Set on `enter()`
   * — explicit `themeId` argument takes precedence; otherwise we fall back
   * to whichever user-selectable theme is marked default on the site. The
   * persistence service uses this when posting saves; if it remains null,
   * the toolbar's Save button stays disabled.
   *
   * Phase 3f wires the URL-based theme chooser to set this via
   * `enter({ themeId })` so admins picking a theme from the admin show page
   * land here with the right target.
   *
   * @type {number|null}
   */
  @tracked activeThemeId = null;

  /**
   * Snapshot of the selected block populated by either the canvas chrome
   * (on click) or the outline panel (on row click). The shape is a loose
   * subset of `{ key, name, id, args, containerArgs, conditions, outletArgs,
   * outletName, metadata }`. Some fields are only available from one entry
   * point — for example, `containerArgs` and `outletArgs` are only set when
   * the selection comes from a rendered block on the canvas.
   *
   * `args` here is the LIVE `entry.args` reference (a `trackedObject`); the
   * inspector reads through it so reads auto-track and edit-time mutations
   * are visible without us re-assigning `selectedBlockData`.
   */
  @tracked selectedBlockData = null;

  /**
   * Monotonically increasing counter bumped on every structural mutation.
   * Consumers (the outline panel, future condition evaluators) read it to
   * open a tracked dep that fires *every* mutation — `_structurallyEdited
   * Outlets.size` only changes on the *first* mutation per outlet, so it
   * isn't enough on its own.
   *
   * @type {number}
   */
  @tracked structuralVersion = 0;
  /**
   * Drag-and-drop session state. Set when the user grabs a block via
   * `editor-draggable`; cleared when the drag ends (success or cancel).
   *
   * `dragSourceKey` opens body-class `--ve-dragging` so the canvas can
   * surface drop zones via CSS. `activeDropTarget` carries the most recent
   * `onDragEnter` payload so the corresponding zone can render its hover
   * styling without each zone needing its own listener.
   *
   * @type {string|null}
   */
  @tracked dragSourceKey = null;
  /** @type {string|null} */
  @tracked dragSourceOutlet = null;
  /** @type {{targetKey: string, position: string, outletName: string}|null} */
  @tracked activeDropTarget = null;
  /**
   * Full drag-source descriptor during an in-flight drag. Browsers
   * restrict `event.dataTransfer.getData()` to the `drop` event for
   * security, so dragover-time consumers (the new
   * `containerDropTarget` modifier, the grid overlay) read this
   * instead. Set by every `dDragAndDropSource` site's
   * `onDragStart` (palette + chrome + outline rows); cleared by
   * `endDrag`.
   *
   * @type {{type: string, data: Object}|null}
   */
  @tracked dragSource = null;
  /**
   * The single source of truth for the drag-time drop indicator. Set
   * by the active scope's dragover handler (a container's
   * `containerDropTarget` modifier OR the `GridOverlay`'s grid-level
   * handler) to the descriptor of the drop that WOULD happen if the
   * user released the mouse right now. The mounted `<DropPreview>`
   * component renders one overlay element off of this; clearing it
   * hides the overlay.
   *
   * Shape:
   * ```
   * {
   *   geometry: { top, left, width, height }, // viewport-relative px
   *   kind: "insert" | "inside" | "replace" | "swap" | "shift" | "occupy",
   *   label: string, // human-readable, already i18n-resolved
   *   variant: "valid",
   *   // Caller-private dispatch payload — read at drop time so the
   *   // drop handler can act on the same descriptor the user saw.
   *   dispatch: {
   *     action: "insertBlock" | "moveBlock" | "fillSlot" |
   *             "moveBlockIntoSlot" | "insertBlockAtCell" |
   *             "moveBlockToCell" | "swapSlotPlacements" | ...,
   *     args: Object,
   *   },
   * }
   * ```
   *
   * Invariant: only one descriptor is set at any time across the
   * whole canvas. Scopes that compute a new descriptor MUST clear
   * the previous one first via `setActiveDropPreview(null)` if their
   * own computation yielded nothing.
   *
   * @type {Object|null}
   */
  @tracked activeDropPreview = null;
  /**
   * Phase 7 simulation slot. When non-null, threads through the condition
   * evaluator's context (via the `EVAL_CONTEXT` debug hook) so
   * condition-gated blocks render as if the simulated user / viewport
   * were active. Block bodies themselves still render with the real
   * user's data — simulation is condition-only.
   *
   * Shape: `{ user, viewport }` — each is null for "use the real value".
   *
   * @type {{user: Object|null, viewport: {viewport: Object, touch: boolean}|null}|null}
   */
  @tracked simulation = null;
  /**
   * Whether the inspector's conditions surface is detached from the
   * right rail and rendered in a floating panel (Phase 7r). Toggled
   * by the inspector's `↗` button and the panel's `↙` redock button.
   * Persisted to localStorage so the preference survives reloads.
   *
   * @type {boolean}
   */
  @tracked conditionsDetached = false;
  /**
   * Floating-panel rect (`{x, y, width, height}`) for the detached
   * conditions surface. Updated by the panel's drag and resize
   * handlers and persisted to localStorage. Null while no rect has
   * been chosen yet — the panel renders centred on first open.
   *
   * @type {{x: number, y: number, width: number, height: number}|null}
   */
  @tracked conditionsPanelRect = null;
  /**
   * Sticky mirror of `activeDropPreview` captured at the moment of
   * the drop's `drop` event. The visible preview is cleared at
   * dragleave / drop start (so the overlay disappears immediately on
   * release), but the dispatch handler needs to read the descriptor
   * one tick later. Same pattern the old `_lastDropPreview` used
   * inside `GridOverlay`.
   *
   * @type {Object|null}
   */
  _lastDropPreview = null;

  /**
   * Clipboard slot for the Cmd/Ctrl-C/X/V cycle and the future "duplicate"
   * action. `mode: "copy"` lets paste re-clone the entry on every Cmd-V,
   * while `mode: "cut"` is currently equivalent at paste time (the cut
   * already removed the source). The distinction lets future polish
   * surface different UI affordances (e.g. visually grey-out the cut
   * source until paste fires).
   *
   * @type {{entry: Object, mode: "copy"|"cut"}|null}
   */
  @tracked _clipboard = null;

  /**
   * Undo / redo stacks for in-memory edits. Entries are discriminated by
   * `kind`:
   *
   * - `{kind: "args", entry, prev, next}` — one batch of arg mutations on a
   *   specific entry. Undo writes `prev` back into `entry.args`, redo flips
   *   to `next`.
   * - `{kind: "structural", changes, prevSelection, nextSelection}` — a
   *   structural mutation (insert / remove / move / duplicate / paste /
   *   conditions / raw-json edit). `changes` is an array of
   *   `{outletName, prevLayout, nextLayout}` pairs. Undo re-publishes the
   *   `prev` layouts; redo re-publishes `next`. Selection is restored
   *   alongside because structural changes can delete or relocate the
   *   selected block.
   *
   * @type {Array<Object>}
   */
  _undoStack = trackedArray();

  /** @type {Array<Object>} */
  _redoStack = trackedArray();

  /**
   * For each entry we've ever mutated, the `entry.args` snapshot taken
   * before the first mutation. Reset / exit walk this map and write those
   * snapshots back into `entry.args`.
   *
   * Stored as a `trackedMap` so reads of `.size` (used by `isDirty`) open
   * a tracked dependency on the collection — that's what keeps the toolbar's
   * Save / Reset buttons reactive to the very first edit.
   *
   * @type {Map<Object, Map<string, *>>}
   */
  _initialSnapshots = trackedMap();

  /**
   * Pending arg changes for the currently-selected block, accumulated across
   * a burst of keystrokes and flushed by `_flushPendingArgs` after a short
   * idle delay. Keys are arg names; values are the latest value typed.
   *
   * @type {Map<string, *>}
   */
  _pendingArgs = new Map();

  /**
   * Outlets where this editor session has materialised a `session-draft`
   * layer. Tracked here (rather than re-derived from the block-outlet
   * record) so `exit` clears exactly what the editor published without
   * touching drafts produced elsewhere.
   *
   * @type {Set<string>}
   */
  _draftedOutlets = new Set();

  /**
   * Names of every outlet whose draft layer has at least one in-memory
   * mutation. Persistence iterates this set on Save to know which outlet
   * layouts to POST. Cleared per-outlet by the persistence service after a
   * successful save, and wholesale on `exit` / `resetAll`.
   *
   * @type {Set<string>}
   */
  _editedOutlets = new Set();

  /**
   * Pristine clones of every drafted outlet's layout, captured at `enter()`
   * time. Used by `resetAll()` to roll structural mutations (drag/drop,
   * insert, delete in later phases) back to the page's pre-edit state.
   *
   * Stored as a separate clone from the draft itself so subsequent edits
   * (which mutate the draft in place) never bleed into the snapshot.
   *
   * @type {Map<string, Array<Object>>}
   */
  _originalLayouts = new Map();

  /**
   * Outlets whose draft has at least one structural mutation (block moved,
   * inserted, deleted). A `trackedSet` so the toolbar's `isDirty` getter
   * reactively responds to the first move — equivalent role to
   * `_initialSnapshots` for arg edits.
   *
   * @type {Set<string>}
   */
  _structurallyEditedOutlets = trackedSet();

  /**
   * `ve:layout` block keys that the author has explicitly asked to
   * render in their full multi-column layout regardless of the
   * `@container` collapse threshold. Editor-only session state — never
   * persisted, cleared on `exit()`. The chrome wrapper picks up the
   * `--force-expanded` modifier class when its block key is in this
   * set, which defeats the universal `@container` collapse rule via
   * specificity so the author can edit the full grid structure.
   *
   * Per-block so authors can independently toggle different layouts.
   *
   * @type {Set<string>}
   */
  _forceExpandedKeys = trackedSet();

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
  _selectionMousedownTarget = null;

  _onCanvasMouseDown = (event) => {
    this._selectionMousedownTarget = event.target;
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
   * `_selectionMousedownTarget`) doesn't deselect.
   *
   * Bound once in `enter()` and removed in `exit()` so the editor
   * adds no global handler weight when inactive.
   *
   * @param {MouseEvent} event
   */
  _onCanvasMouseUp = (event) => {
    const downTarget = this._selectionMousedownTarget;
    this._selectionMousedownTarget = null;
    if (!this.isActive || !this.selectedBlockKey) {
      return;
    }
    if (this._isInsideAllowedScope(downTarget)) {
      return;
    }
    if (this._isInsideAllowedScope(event.target)) {
      return;
    }
    this.selectBlock(null);
  };

  constructor() {
    super(...arguments);
    this._loadConditionsPanelState();
  }

  _isInsideAllowedScope(target) {
    if (!(target instanceof Element)) {
      return false;
    }
    return Boolean(
      target.closest(".visual-editor-block-chrome") ||
      target.closest(".visual-editor-shell") ||
      target.closest(".visual-editor-conditions-floating-panel") ||
      // Float-Kit portals (menus / modals / tooltips) mount at body
      // level, outside the shell. They're conceptually part of the
      // editor surface (an icon picker, a colour swatch dropdown,
      // a hover tooltip) so clicks inside them must NOT deselect.
      target.closest(".fk-d-menu") ||
      target.closest(".fk-d-menu-modal") ||
      target.closest(".fk-d-tooltip")
    );
  }

  /**
   * Toggles the conditions detach state. Reads / writes localStorage
   * so the preference survives reloads.
   */
  @action
  toggleConditionsDetached() {
    this.conditionsDetached = !this.conditionsDetached;
    this._persistConditionsPanelState();
  }

  @action
  closeConditionsPanel() {
    this.conditionsDetached = false;
    this._persistConditionsPanelState();
  }

  @action
  updateConditionsPanelRect(rect) {
    this.conditionsPanelRect = rect;
    this._persistConditionsPanelState();
  }

  /**
   * Hydrates the conditions panel state from localStorage on service
   * init. Tolerates missing / malformed entries by leaving the
   * defaults in place.
   */
  _loadConditionsPanelState() {
    try {
      const raw = localStorage.getItem("visual-editor.conditions-panel");
      if (!raw) {
        return;
      }
      const parsed = JSON.parse(raw);
      if (typeof parsed?.detached === "boolean") {
        this.conditionsDetached = parsed.detached;
      }
      if (parsed?.rect && typeof parsed.rect === "object") {
        this.conditionsPanelRect = parsed.rect;
      }
    } catch {
      // Corrupt JSON in localStorage — ignore, keep defaults.
    }
  }

  _persistConditionsPanelState() {
    try {
      localStorage.setItem(
        "visual-editor.conditions-panel",
        JSON.stringify({
          detached: this.conditionsDetached,
          rect: this.conditionsPanelRect,
        })
      );
    } catch {
      // QuotaExceeded / disabled storage — non-fatal, the preference
      // just won't survive the session.
    }
  }

  /**
   * Whether the current user is allowed to use the editor. Staff are always
   * allowed. Non-staff users must belong to at least one of the groups listed
   * in the `visual_editor_allowed_groups` site setting. The plugin must also
   * be enabled via `visual_editor_enabled`.
   *
   * @returns {boolean}
   */
  get canEdit() {
    if (!this.siteSettings.visual_editor_enabled) {
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
    const allowed = (this.siteSettings.visual_editor_allowed_groups || "")
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
   * either one that already has a registered layout (the historical
   * criterion) or one whose `<BlockOutlet>` is mounted in the DOM with no
   * layout yet. Including the empty-mounted case is what makes "start a
   * layout from scratch" possible: previously the entry pill stayed
   * hidden until *some* code path called `api.renderBlocks(...)` first.
   *
   * Mounted outlets that aren't registered are silently ignored (they
   * can't have a layout, so they shouldn't appear in the editor).
   *
   * @returns {string[]}
   */
  get editableOutlets() {
    const registered = this.blocks.listOutlets();
    const mounted = mountedOutletNames();
    return registered.filter(
      (name) => this.blocks.hasLayout(name) || mounted?.has(name)
    );
  }

  @action
  enter({ themeId } = {}) {
    if (!this.canEdit) {
      return;
    }
    this.isActive = true;
    this.activeThemeId = themeId ?? this._defaultThemeId();
    document.body.classList.add("visual-editor-active");
    document.addEventListener("mousedown", this._onCanvasMouseDown);
    document.addEventListener("mouseup", this._onCanvasMouseUp);
    this._materializeAllDrafts();
  }

  /**
   * Picks a default theme id for editor sessions that didn't supply one.
   * Reads from the `activatedThemes` preload — the server-resolved active
   * theme stack for this request, ordered parent-first by
   * `Theme.transform_ids`. The first id is the parent theme (the one the
   * page is actually rendering against), which is exactly what we want to
   * save edits to.
   *
   * Falls back to the user-selectable themes list when activatedThemes is
   * unavailable (legacy preload format) or empty. Returns null when no
   * themes are available, in which case the Save button stays disabled.
   *
   * @returns {number|null}
   */
  _defaultThemeId() {
    const activated = PreloadStore.get("activatedThemes");
    if (activated && typeof activated === "object") {
      const ids = Object.keys(activated)
        .map((id) => parseInt(id, 10))
        .filter((id) => Number.isFinite(id) && id > 0);
      if (ids.length > 0) {
        return ids[0];
      }
    }
    const themes = this.site?.user_themes ?? [];
    return (
      themes.find((t) => t.default)?.theme_id ?? themes[0]?.theme_id ?? null
    );
  }

  /**
   * Eagerly publishes a `session-draft` layer for every outlet that has a
   * resolved layout. After this runs, `_getOutletLayouts()` returns draft
   * entries for those outlets — the rest of the editor session mutates
   * those drafts in place via `trackedObject`, so no further layer swap
   * happens during typing.
   *
   * Idempotent: running over already-drafted outlets is a no-op (skipped by
   * the `_draftedOutlets` check). Invoked from `enter()`.
   */
  _materializeAllDrafts() {
    for (const outletName of this.editableOutlets) {
      if (this._draftedOutlets.has(outletName)) {
        continue;
      }
      const layout = this.readResolvedLayout(outletName);
      // Outlets that are mounted but have no registered layout get an
      // empty draft seeded here, so the outline lists them with zero
      // rows and the canvas accepts drops on the outlet boundary
      // immediately. Without this seed an empty outlet would only get
      // a draft the first time something tried to write to it.
      const draftLayout = layout ? cloneLayoutForDraft(layout) : [];
      // Second clone, never published. Held as the rollback target for
      // `resetAll()` — we can't capture the draft itself because in-place
      // arg mutations would leak into the snapshot.
      this._originalLayouts.set(
        outletName,
        layout ? cloneLayoutForDraft(layout) : []
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
        // validation as warned and keeps the layout rendering. See
        // `plugins/discourse-visual-editor/docs/PLAN.md` Phase 5.
        { permissive: true }
      );
      this._draftedOutlets.add(outletName);
    }
  }

  /**
   * Ensures a session-draft layer exists for `outletName`. Used by
   * mutation actions that target outlets the user is populating from
   * scratch — those outlets have no published layout (so
   * `_materializeAllDrafts` skips them on `enter()`), but the
   * editor's empty-outlet drop zone (Phase 7p.1) lets authors add
   * the first block. We mint an empty draft `[]` here so the
   * subsequent `_publishStructuralChange` has somewhere to land.
   *
   * Idempotent: bails when a draft already exists.
   *
   * @param {string} outletName
   * @returns {Array<Object>} the layout array (existing or freshly minted).
   */
  _ensureDraft(outletName) {
    const existing = this.readResolvedLayout(outletName);
    if (existing) {
      return existing;
    }
    const emptyDraft = [];
    this._originalLayouts.set(outletName, []);
    _setLayoutLayer(
      outletName,
      LAYOUT_LAYERS.SESSION_DRAFT,
      emptyDraft,
      getOwner(this),
      { permissive: true }
    );
    this._draftedOutlets.add(outletName);
    return this.readResolvedLayout(outletName) ?? emptyDraft;
  }

  @action
  exit() {
    // Roll back any in-memory mutations recorded in initial snapshots. With
    // session-drafts active, the underlying entries weren't actually
    // mutated, so this is effectively a no-op for the production path
    // (we're about to drop the drafts anyway). For test paths that bypass
    // `enter()` and mutate code-default entries directly, this restores
    // them so test isolation holds.
    for (const [entry, snapshot] of this._initialSnapshots) {
      this._writeArgs(entry, snapshot);
    }

    // Clear session-drafts. The underlying theme/code-default layer becomes
    // resolved again, displaying whatever was there before the editor
    // opened — in-memory mutations live ONLY on draft entries, so dropping
    // the drafts discards the mutations cleanly.
    for (const outletName of this._draftedOutlets) {
      _clearLayoutLayer(outletName, LAYOUT_LAYERS.SESSION_DRAFT);
    }
    this._draftedOutlets.clear();

    this.isActive = false;
    this.activeThemeId = null;
    this.selectedBlockKey = null;
    this.selectedBlockData = null;
    this.dragSourceKey = null;
    this.dragSourceOutlet = null;
    this.activeDropTarget = null;
    this._undoStack.length = 0;
    this._redoStack.length = 0;
    this._initialSnapshots.clear();
    this._pendingArgs.clear();
    this._editedOutlets.clear();
    this._originalLayouts.clear();
    this._structurallyEditedOutlets.clear();
    this._forceExpandedKeys.clear();
    document.body.classList.remove("visual-editor-active");
    document.removeEventListener("mousedown", this._onCanvasMouseDown);
    document.removeEventListener("mouseup", this._onCanvasMouseUp);
    this._selectionMousedownTarget = null;
  }

  /** @returns {boolean} */
  get canUndo() {
    return this._undoStack.length > 0;
  }

  /** @returns {boolean} */
  get canRedo() {
    return this._redoStack.length > 0;
  }

  /** @returns {boolean} */
  get isDirty() {
    return (
      this._initialSnapshots.size > 0 ||
      this._structurallyEditedOutlets.size > 0
    );
  }

  /** @returns {boolean} */
  get isDragging() {
    return this.dragSourceKey != null;
  }

  /**
   * Validation warnings captured by `_setLayoutLayer({permissive: true})`
   * across every outlet that the editor is currently drafting. Walks the
   * resolved layer entries, harvests each entry's `validationWarnings`,
   * and returns a flat list keyed by outlet for the toolbar / save-dialog
   * UX.
   *
   * Reactivity: reads `structuralVersion` (bumped on every structural
   * mutation) so a fresh draft publish causes the toolbar to re-evaluate.
   * Validation itself is async (the layer entry's `validatedLayout` is a
   * lazy Promise that resolves after `BlockOutlet` first reads it). On the
   * very first render after a publish the warnings array may not yet be
   * populated; the next `structuralVersion` tick or a subsequent re-read
   * surfaces them. This is acceptable for a status indicator — the page
   * doesn't crash either way.
   *
   * @returns {Array<{outletName: string, message: string}>}
   */
  get validationWarnings() {
    // Open the tracked dep so structural mutations re-run this getter.
    void this.structuralVersion;
    const layoutMap = _getOutletLayouts();
    const warnings = [];
    for (const [outletName, record] of layoutMap) {
      for (const w of record?.validationWarnings ?? []) {
        warnings.push({ outletName, message: w.message });
      }
    }
    return warnings;
  }

  /** @returns {boolean} */
  get hasValidationWarnings() {
    return this.validationWarnings.length > 0;
  }

  /**
   * Soft-failure metadata for the currently-selected block, or `null` if
   * the selection is healthy (or nothing is selected). Reads
   * `__failureType` / `__failureReason` written by the validator when
   * running in permissive mode — far more accurate than text-matching
   * the whole-outlet warning list against the selected block's name.
   *
   * @returns {{failureType: string, failureReason: string}|null}
   */
  get selectedBlockFailure() {
    void this.structuralVersion;
    const key = this.selectedBlockKey;
    if (!key) {
      return null;
    }
    const located = this._findEntryAndOutletSync(key);
    const entry = located?.entry;
    if (!entry?.__failureType) {
      return null;
    }
    return {
      failureType: entry.__failureType,
      failureReason: entry.__failureReason ?? "",
    };
  }

  /**
   * Removes the block matching `blockKey` from whichever outlet currently
   * holds it. Used by the inspector's recovery actions (e.g. "Remove
   * empty container") and by future delete affordances. Routes through
   * `_publishStructuralChange` so the bookkeeping (edited-outlets,
   * structural-version, isDirty signal) matches a drag-driven move.
   *
   * @param {string} blockKey
   * @returns {boolean} true on success
   */
  /**
   * Sibling-relative move helpers used by the floating block toolbar
   * (Phase 7p.2). Each looks up the selected entry's siblings and
   * computes a `moveBlock` call against the previous / next sibling.
   *
   * Returns `false` (no-op) when the block is already first / last in
   * its parent, when no block is selected, or when the move would
   * otherwise be rejected.
   *
   * @param {string} blockKey
   * @returns {boolean}
   */
  @action
  moveBlockUp(blockKey) {
    const located = this._findEntryAndOutletSync(blockKey);
    if (!located) {
      return false;
    }
    const layout = this.readResolvedLayout(located.outletName);
    if (!layout) {
      return false;
    }
    const sibs = findEntrySiblings(layout, blockKey);
    if (!sibs || sibs.index === 0) {
      return false;
    }
    const previousKey = entryKey(sibs.siblings[sibs.index - 1]);
    return this.moveBlock({
      sourceKey: blockKey,
      targetKey: previousKey,
      position: "before",
      targetOutletName: located.outletName,
    });
  }

  /**
   * @param {string} blockKey
   * @returns {boolean}
   */
  @action
  moveBlockDown(blockKey) {
    const located = this._findEntryAndOutletSync(blockKey);
    if (!located) {
      return false;
    }
    const layout = this.readResolvedLayout(located.outletName);
    if (!layout) {
      return false;
    }
    const sibs = findEntrySiblings(layout, blockKey);
    if (!sibs || sibs.index >= sibs.siblings.length - 1) {
      return false;
    }
    const nextKey = entryKey(sibs.siblings[sibs.index + 1]);
    return this.moveBlock({
      sourceKey: blockKey,
      targetKey: nextKey,
      position: "after",
      targetOutletName: located.outletName,
    });
  }

  /**
   * Whether the selected block has a sibling above it. Drives the
   * `Move up` toolbar button's disabled state.
   *
   * @returns {boolean}
   */
  get canMoveSelectedUp() {
    return this._selectionSiblingIndex() > 0;
  }

  /**
   * Whether the selected block has a sibling below it. Drives the
   * `Move down` toolbar button's disabled state.
   *
   * @returns {boolean}
   */
  get canMoveSelectedDown() {
    const idx = this._selectionSiblingIndex();
    if (idx < 0) {
      return false;
    }
    const located = this._findEntryAndOutletSync(this.selectedBlockKey);
    if (!located) {
      return false;
    }
    const layout = this.readResolvedLayout(located.outletName);
    const sibs = findEntrySiblings(layout, this.selectedBlockKey);
    return sibs ? idx < sibs.siblings.length - 1 : false;
  }

  /**
   * Path of ancestor segments from the outlet root down to the
   * selected block. Used by the canvas-bottom breadcrumb. Each segment
   * carries `{key, blockName, displayName, isOutlet, outletName}`.
   * Outlet segment is first (`isOutlet: true`, `key: null`), nested
   * containers follow, selected block is last.
   *
   * @returns {Array<{key: string|null, blockName: string|null, displayName: string, isOutlet: boolean, outletName: string|null}>}
   */
  get selectedBlockAncestry() {
    // Read structuralVersion so this re-evaluates after every mutation.
    // eslint-disable-next-line no-unused-vars
    const _v = this.structuralVersion;
    const key = this.selectedBlockKey;
    if (!key) {
      return [];
    }
    const located = this._findEntryAndOutletSync(key);
    if (!located) {
      return [];
    }
    const layout = this.readResolvedLayout(located.outletName);
    if (!layout) {
      return [];
    }
    const path = findAncestryPath(layout, key);
    if (!path) {
      return [];
    }
    return [
      {
        key: null,
        blockName: null,
        displayName: located.outletName,
        isOutlet: true,
        outletName: located.outletName,
      },
      ...path.map((entry) => {
        const meta = this._metadataFor(entry);
        const blockName =
          meta?.blockName ??
          (typeof entry.block === "string" ? entry.block : "(block)");
        return {
          key: entryKey(entry),
          blockName,
          displayName: meta?.shortName ?? blockName,
          isOutlet: false,
          outletName: located.outletName,
        };
      }),
    ];
  }

  /**
   * @returns {number} the selected block's index among its siblings, or
   *   `-1` when nothing is selected / locatable.
   */
  _selectionSiblingIndex() {
    // Read `structuralVersion` so this getter re-evaluates after every
    // structural mutation — keeps the toolbar's move buttons reactive.
    // eslint-disable-next-line no-unused-vars
    const _v = this.structuralVersion;
    const key = this.selectedBlockKey;
    if (!key) {
      return -1;
    }
    const located = this._findEntryAndOutletSync(key);
    if (!located) {
      return -1;
    }
    const layout = this.readResolvedLayout(located.outletName);
    if (!layout) {
      return -1;
    }
    const sibs = findEntrySiblings(layout, key);
    return sibs?.index ?? -1;
  }

  /**
   * Inserts a fresh clone of the given block immediately after it in
   * the layout. Used by the block toolbar's `Duplicate` button.
   *
   * @param {string} blockKey
   * @returns {boolean}
   */
  @action
  duplicateBlock(blockKey) {
    const located = this._findEntryAndOutletSync(blockKey);
    if (!located) {
      return false;
    }
    return this._recordStructural([located.outletName], () => {
      const layout = this.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const insertion = insertEntryAt(
        layout,
        blockKey,
        cloneEntryForPaste(located.entry),
        "after"
      );
      if (!insertion.changed) {
        return false;
      }
      this._publishStructuralChange(located.outletName, insertion.layout);
      return true;
    });
  }

  @action
  removeBlock(blockKey) {
    const located = this._findEntryAndOutletSync(blockKey);
    if (!located) {
      return false;
    }
    return this._recordStructural([located.outletName], () => {
      const layout = this.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      // Multi-cell placements get preserved as `ve:slot` drop targets
      // on delete — that keeps the author's layout shape (a hero
      // spanning 3 columns, a sidebar rail, etc.) intact even when
      // the content inside it is removed. Single-cell deletes fall
      // through to a normal removal; the grid overlay's auto-empty
      // cell rendering already surfaces those positions as drop
      // targets.
      const result = this._shouldRestoreAsSlot(layout, located.entry, blockKey)
        ? replaceEntryInPlace(layout, blockKey, {
            block: "ve:slot",
            containerArgs: located.entry.containerArgs,
          })
        : removeEntry(layout, blockKey);
      if (!result.changed) {
        return false;
      }
      if (this.selectedBlockKey === blockKey) {
        this.selectBlock(null);
      }
      this._publishStructuralChange(located.outletName, result.layout);
      return true;
    });
  }

  /**
   * Returns true when removing `entry` from `layout` should leave a
   * `ve:slot` placeholder at the same position instead of clearing
   * the cell entirely. All four conditions must hold:
   *
   *   1. The entry isn't already a `ve:slot` — deleting a slot is the
   *      author saying "I don't want this drop target", not "regenerate
   *      one".
   *   2. The placement spans more than one cell (column span > 1 OR
   *      row span > 1). Single-cell positions are already discoverable
   *      via the grid overlay's auto-empty cell rendering; we only
   *      need an explicit slot when the rect is too large for the
   *      auto-detection to reconstruct.
   *   3. The placement fits within the parent grid's `columns` /
   *      `rows`. Restoring a slot that overflows the grid would just
   *      produce another `--out-of-bounds` warning.
   *   4. The placement doesn't overlap any sibling's placement.
   *      Stacking two cells at the same rect is already a
   *      malformed state; we don't want to perpetuate it.
   *
   * @param {Array<Object>} layout
   * @param {Object} entry
   * @param {string} entryKeyValue - The entry's composite key.
   * @returns {boolean}
   */
  _shouldRestoreAsSlot(layout, entry, entryKeyValue) {
    if (!entry || entry.block === "ve:slot") {
      return false;
    }
    const placement = parsePlacement(entry.containerArgs);
    const cs = placement.column.start;
    const ce = placement.column.end;
    const rs = placement.row.start;
    const re = placement.row.end;
    if (cs == null || ce == null || rs == null || re == null) {
      return false;
    }
    const colSpan = ce - cs;
    const rowSpan = re - rs;
    if (colSpan <= 1 && rowSpan <= 1) {
      return false;
    }
    // Walk to the parent grid via the ancestry chain. The immediate
    // parent of the entry is at the second-to-last position; its
    // `args.columns` / `args.rows` are the bounds we check against.
    const chain = findAncestryPath(layout, entryKeyValue);
    if (!chain || chain.length < 2) {
      return false;
    }
    const parent = chain[chain.length - 2];
    const cols = Number(parent.args?.columns);
    const rows = Number(parent.args?.rows);
    if (!Number.isFinite(cols) || !Number.isFinite(rows)) {
      return false;
    }
    if (cs < 1 || rs < 1 || ce > cols + 1 || re > rows + 1) {
      return false;
    }
    // Sibling overlap check. The entry itself is in `parent.children`;
    // skip it during the walk.
    for (const sibling of parent.children ?? []) {
      if (sibling === entry) {
        continue;
      }
      if (placementsOverlap(placement, parsePlacement(sibling.containerArgs))) {
        return false;
      }
    }
    return true;
  }

  /**
   * Replaces the `conditions` tree on the currently-selected block.
   * Used by the visual condition builder in the inspector to push edits
   * back to the layout. Pass `null` to clear all conditions.
   *
   * Conditions affect *whether* a block renders, so this is a structural
   * change — routes through `_publishStructuralChange` to keep
   * `isDirty`, `structuralVersion`, and the outline's row count in
   * lockstep with the canvas.
   *
   * NOTE: we deliberately do NOT reassign `selectedBlockData` here. The
   * inspector's args form (`<InspectorForm>`) reads
   * `selectedBlockData.argsSnapshot` as `<Form @data>`; spreading into a
   * new object would force FormKit to remount and re-register its
   * fields, hitting "name already in use" duplicate-registration errors.
   * Instead, callers that need the freshest conditions tree read
   * through `selectedBlockConditions` — a live getter that resolves the
   * latest entry on every read.
   *
   * @param {Array|Object|null} newConditions
   * @returns {boolean} true on success, false when no block is selected
   *   or the selection isn't locatable in the live layout.
   */
  @action
  updateSelectedConditions(newConditions) {
    const key = this.selectedBlockKey;
    if (!key) {
      return false;
    }
    const located = this._findEntryAndOutletSync(key);
    if (!located) {
      return false;
    }
    return this._recordStructural([located.outletName], () => {
      const layout = this.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const result = replaceEntryConditions(layout, key, newConditions);
      if (!result.changed) {
        return false;
      }
      this._publishStructuralChange(located.outletName, result.layout);
      return true;
    });
  }

  /**
   * Sets the `id` property on the selected entry. Validates against
   * `VALID_BLOCK_ID_PATTERN` (lowercase letters / digits / hyphens,
   * starting with a letter — same shape as block names). Empty / null
   * clears the property entirely.
   *
   * Returns `{ ok, error }` so the caller (the inspector's metadata
   * section) can show inline validation feedback without poking the
   * service for state.
   *
   * @param {string|null} nextId
   * @returns {{ok: boolean, error: string|null}}
   */
  @action
  updateSelectedEntryId(nextId) {
    const key = this.selectedBlockKey;
    if (!key) {
      return { ok: false, error: "no-selection" };
    }
    const trimmed = typeof nextId === "string" ? nextId.trim() : nextId;
    if (trimmed && !VALID_BLOCK_ID_PATTERN.test(trimmed)) {
      return { ok: false, error: "invalid-format" };
    }
    const located = this._findEntryAndOutletSync(key);
    if (!located) {
      return { ok: false, error: "not-found" };
    }
    const committed = this._recordStructural([located.outletName], () => {
      const layout = this.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const result = replaceEntryId(layout, key, trimmed || null);
      if (!result.changed) {
        return false;
      }
      this._publishStructuralChange(located.outletName, result.layout);
      return true;
    });
    return { ok: !!committed, error: null };
  }

  /**
   * Replaces the selected entry with a wholly new entry object. Used
   * by the inspector's Raw JSON tab — the author edits the entry's
   * serialised form and commits the parsed result.
   *
   * Routes through `_publishStructuralChange` because changes can
   * touch any field (args / conditions / classNames / id), and the
   * outline / canvas need to refresh.
   *
   * @param {Object} parsed - The parsed JSON, already validated by
   *   the caller (`InspectorRawJson` rejects invalid JSON without
   *   calling us).
   * @returns {boolean}
   */
  @action
  replaceSelectedEntryRaw(parsed) {
    const key = this.selectedBlockKey;
    if (!key) {
      return false;
    }
    const located = this._findEntryAndOutletSync(key);
    if (!located) {
      return false;
    }
    return this._recordStructural([located.outletName], () => {
      const layout = this.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const result = replaceEntryInPlace(layout, key, parsed);
      if (!result.changed) {
        return false;
      }
      this._publishStructuralChange(located.outletName, result.layout);
      return true;
    });
  }

  /**
   * The selected entry's current serialised form, for the Raw JSON
   * inspector tab. Uses the same `serializeEntryForSave` that
   * `persistance` uses for the wire format — so what you see in the
   * Raw JSON tab matches what gets saved. Class references on
   * `entry.block` are normalised to their registered name strings,
   * and runtime-only fields (`__stableKey`, `__visible`, ...) are
   * dropped. Reads `structuralVersion` to refresh on every mutation.
   *
   * @returns {Object|null}
   */
  get selectedBlockRawEntry() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.structuralVersion;
    const key = this.selectedBlockKey;
    if (!key) {
      return null;
    }
    const located = this._findEntryAndOutletSync(key);
    if (!located) {
      return null;
    }
    return serializeEntryForSave(located.entry);
  }

  /**
   * Live conditions tree for the currently-selected block. Re-resolves
   * the entry on every read so structural changes (publishes from
   * `updateSelectedConditions`, moves, etc.) are picked up automatically
   * by the condition builder's `@cached get tree()` via the
   * `structuralVersion` tracked dep.
   *
   * @returns {Array|Object|null}
   */
  get selectedBlockConditions() {
    // Force a tracked read so consumers re-render when structural
    // mutations re-publish.
    // eslint-disable-next-line no-unused-vars
    const _v = this.structuralVersion;
    const key = this.selectedBlockKey;
    if (!key) {
      return null;
    }
    const located = this._findEntryAndOutletSync(key);
    if (!located) {
      return this.selectedBlockData?.conditions ?? null;
    }
    return located.entry.conditions ?? null;
  }

  /**
   * Indicates whether the clipboard currently holds anything that
   * `pasteFromClipboard` could insert. Reactivity comes from `_clipboard`
   * being tracked.
   *
   * @returns {boolean}
   */
  get hasClipboardEntry() {
    return this._clipboard != null;
  }

  /**
   * Captures the currently-selected block onto the clipboard for later
   * paste. The captured entry is a fresh deep clone with stable keys
   * stripped, so subsequent mutations on the canvas don't leak into the
   * clipboard payload.
   *
   * @returns {boolean} true on success, false when no block is selected
   */
  @action
  copySelected() {
    const key = this.selectedBlockKey;
    if (!key) {
      return false;
    }
    const located = this._findEntryAndOutletSync(key);
    if (!located) {
      return false;
    }
    this._clipboard = {
      entry: cloneEntryForPaste(located.entry),
      mode: "copy",
    };
    return true;
  }

  /**
   * Captures the currently-selected block onto the clipboard AND removes
   * it from the canvas. The clipboard mode is `"cut"` so callers can
   * differentiate from a pure copy if they want different UI
   * affordances; at paste time the two modes behave identically (the
   * source is already gone).
   *
   * @returns {boolean} true on success, false when no block is selected
   */
  @action
  cutSelected() {
    const key = this.selectedBlockKey;
    if (!key) {
      return false;
    }
    const located = this._findEntryAndOutletSync(key);
    if (!located) {
      return false;
    }
    this._clipboard = {
      entry: cloneEntryForPaste(located.entry),
      mode: "cut",
    };
    return this.removeBlock(key);
  }

  /**
   * Inserts a fresh clone of the clipboard entry adjacent to the current
   * selection (after it, in the selected block's outlet). Each paste
   * re-clones the clipboard payload, so multiple `Cmd+V` taps insert
   * independent subtrees rather than aliasing the same node.
   *
   * Requires a selection. Returns false when there's nothing on the
   * clipboard, no block is currently selected, or the insert otherwise
   * no-ops (e.g. the selected block isn't locatable in the live layout).
   *
   * @returns {boolean}
   */
  @action
  pasteFromClipboard() {
    if (!this._clipboard) {
      return false;
    }
    const targetKey = this.selectedBlockKey;
    if (!targetKey) {
      return false;
    }
    const located = this._findEntryAndOutletSync(targetKey);
    if (!located) {
      return false;
    }
    return this._recordStructural([located.outletName], () => {
      const layout = this.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const insertion = insertEntryAt(
        layout,
        targetKey,
        cloneEntryForPaste(this._clipboard.entry),
        "after"
      );
      if (!insertion.changed) {
        return false;
      }
      this._publishStructuralChange(located.outletName, insertion.layout);
      return true;
    });
  }

  /**
   * Whether simulation mode is currently active. True when either the
   * persona or the viewport slot has been deliberately set (a slot
   * holding `null` means "explicitly anonymous / explicitly real"
   * rather than "unset"; absence of the key means "unset").
   */
  get isSimulating() {
    return this.simulation != null;
  }

  /**
   * Sets the persona portion of the simulation.
   *
   * Three states:
   *   - `undefined` → clears the persona slot (real `currentUser` is used).
   *   - `null` → simulates an anonymous viewer.
   *   - `{...}` → simulates that specific user object.
   *
   * @param {Object|null|undefined} user
   */
  @action
  setSimulatedUser(user) {
    this.simulation = this._patchSimulation(this.simulation, "user", user);
    this._bumpStructuralVersion();
  }

  /**
   * Sets the viewport portion of the simulation. Pass `undefined` to
   * clear it and fall back to the real `capabilities` service.
   *
   * @param {{viewport: Object, touch: boolean}|null|undefined} viewport
   */
  @action
  setSimulatedViewport(viewport) {
    this.simulation = this._patchSimulation(
      this.simulation,
      "viewport",
      viewport
    );
    this._bumpStructuralVersion();
  }

  /**
   * Clears both the persona and viewport slots, exiting simulation mode.
   */
  @action
  clearSimulation() {
    this.simulation = null;
    this._bumpStructuralVersion();
  }

  /**
   * Internal: applies a single-key patch to the simulation slot. Treats
   * `undefined` as "delete the key" (since `null` is the meaningful
   * sentinel for anonymous / real). When every slot is unset, returns
   * `null` so `isSimulating` flips to `false` cleanly.
   *
   * @param {Object|null} current
   * @param {string} key
   * @param {*} value
   * @returns {Object|null}
   */
  _patchSimulation(current, key, value) {
    const next = { ...(current ?? {}) };
    if (value === undefined) {
      delete next[key];
    } else {
      next[key] = value;
    }
    if (!("user" in next) && !("viewport" in next)) {
      return null;
    }
    return next;
  }

  /**
   * Internal: bumps `structuralVersion` so any consumer subscribed to it
   * (outline panel, outlets panel, etc.) re-renders against the new
   * simulation. The condition evaluator itself reads the live
   * `this.simulation` getter via the EVAL_CONTEXT callback, so its
   * re-evaluation is also automatic via tracked reads.
   */
  _bumpStructuralVersion() {
    this.structuralVersion = this.structuralVersion + 1;
  }

  @action
  toggle() {
    if (this.isActive) {
      this.exit();
    } else {
      this.enter();
    }
  }

  @action
  selectBlock(data) {
    // Flush anything still pending from a previous selection so we don't
    // apply those keystrokes to the new block by accident.
    if (this._pendingArgs.size > 0) {
      this._flushPendingArgs();
    }
    this.selectedBlockKey = data?.key ?? null;

    if (!data) {
      this.selectedBlockData = null;
      return;
    }

    // Bind `args` to the LIVE `entry.args` (a `trackedObject`) so consumers
    // that need a live read (canvas-side, undo restoration, etc.) see
    // current values. Walks `_getOutletLayouts()`, which returns the
    // resolved entry per outlet — so when session-drafts are active, we
    // bind to the draft entry, not the underlying layer's.
    const liveData = { ...data };
    this._bindLiveArgs(liveData);

    // Snapshot the args at selection time as a plain object. `argsSnapshot`
    // is what we hand to FormKit's `<Form @data>` — FormKit's immer-based
    // FKFormData rejects proxies, and reading `argsSnapshot` doesn't open
    // tracked deps on the underlying `entry.args` trackedObject. That keeps
    // the inspector's `values` getter from re-evaluating on every keystroke
    // (which would otherwise trigger Form's render path, costing the input
    // its focus).
    liveData.argsSnapshot = liveData.args ? { ...liveData.args } : {};

    // Same snapshot treatment for `containerArgs` — the inspector's
    // placement form takes the bag as `<Form @data>` and re-rendering it on
    // every keystroke would tear down inputs. We deep-snapshot one level
    // per namespace so each form sees a stable plain object.
    liveData.containerArgsSnapshot = liveData.containerArgs
      ? Object.fromEntries(
          Object.entries(liveData.containerArgs).map(([ns, bag]) => [
            ns,
            bag !== null && typeof bag === "object" ? { ...bag } : bag,
          ])
        )
      : {};

    // Resolve the parent's `childArgs` schema so the inspector can render
    // a placement section per namespace the parent declares.
    liveData.parentChildArgsSchema = this._resolveParentChildArgsSchema(
      liveData.key
    );

    // Snapshot the parent's `args` so the inspector form can evaluate
    // `ui.conditional: { arg: "mode", equals: "grid" }` against the parent's
    // current mode. Bumping the structural version doesn't matter here
    // because changing the parent's mode strips this child's
    // `containerArgs.grid`, which forces a re-selection anyway.
    const parentEntry = this._findEntryParent(liveData.key);
    liveData.parentArgsSnapshot = parentEntry?.args
      ? { ...parentEntry.args }
      : {};

    // Augment metadata with an inferred args schema when the block didn't
    // declare one. We do this at selection time (not in the inspector form)
    // so the schema is a stable reference across the live keystroke session.
    // Without this, the inspector would re-compute its schema on every edit,
    // causing the FormKit `<form.Field>` components to remount — which would
    // tear down the input the user is typing in and trigger
    // "@name=... already in use" errors on rapid reselect.
    this.selectedBlockData = this._withInferredMetadata(liveData);
  }

  /**
   * Resolves `data.key` against the registered layouts and rebinds `data.args`
   * to the live entry's `args` (a `trackedObject`). The `findEntry` walk is
   * synchronous when validation has already completed (which it has by the
   * time the user can click a block). On the rare path where validation is
   * still pending we leave `data.args` as-is — the inspector renders against
   * the snapshot the caller passed in, and the next mutation flush picks up
   * the live binding.
   */
  _bindLiveArgs(data) {
    if (!data?.key) {
      return;
    }
    const layoutMap = _getOutletLayouts();
    for (const [, record] of layoutMap) {
      const layout = record.layout;
      if (!layout) {
        continue;
      }
      const found = findEntry(layout, data.key);
      if (found) {
        data.args = found.args;
        data.containerArgs = found.containerArgs ?? null;
        return;
      }
    }
  }

  /**
   * Resolves the parent block's `childArgs` schema for the selected entry,
   * so the inspector can render a placement section (one form per top-level
   * namespace declared by the parent). Returns `null` when the entry sits at
   * the outlet root or when the parent doesn't declare a childArgs schema.
   *
   * Handles both forms of `parent.block`: a class reference (decorated
   * blocks passed by class to `api.renderBlocks`) and a registered name
   * string (everything that's been through serialisation, including
   * theme-shipped layouts and the editor's own draft layer).
   *
   * @param {string} key
   * @returns {Object|null}
   */
  _resolveParentChildArgsSchema(key) {
    const parent = this._findEntryParent(key);
    if (!parent) {
      return null;
    }
    const parentName = this._blockNameOf(parent);
    if (!parentName) {
      return null;
    }
    return this._metadataForName(parentName)?.childArgs ?? null;
  }

  _withInferredMetadata(data) {
    const declared = data.metadata?.args;
    if (declared && Object.keys(declared).length > 0) {
      return data;
    }
    const args = data.args ?? {};
    if (Object.keys(args).length === 0) {
      return data;
    }
    return {
      ...data,
      metadata: {
        ...(data.metadata ?? {}),
        args: inferSchemaFromValues(args),
      },
    };
  }

  /**
   * Tells whether a given block key matches the current selection.
   *
   * Decorated with `@action` so that Glimmer template subexpressions like
   * `(this.visualEditor.isBlockSelected row.blockKey)` keep the correct
   * `this` binding. Without it Glimmer extracts the bare function reference
   * and calls it without context, which throws when the body reads
   * `this.selectedBlockKey`.
   *
   * @param {string|null} key - The composite block key (`${name}:${__stableKey}`).
   * @returns {boolean}
   */
  @action
  isBlockSelected(key) {
    return this.selectedBlockKey != null && this.selectedBlockKey === key;
  }

  /**
   * Records a pending arg change for the currently-selected block and
   * schedules a debounced flush. A burst of keystrokes within
   * `FLUSH_DELAY_MS` collapses into a single batch — applied to
   * `entry.args` at flush time. Because `entry.args` is a `trackedObject`
   * and the curried block reads through reactive getters, the canvas
   * updates without re-rendering anything else.
   *
   * @param {string} argName
   * @param {*} value
   */
  @action
  updateSelectedArg(argName, value) {
    if (!this.selectedBlockKey) {
      return;
    }
    this._pendingArgs.set(argName, value);
    discourseDebounce(this, this._flushPendingArgs, FLUSH_DELAY_MS);
  }

  /**
   * Updates one field inside a `containerArgs` namespace bag of the selected
   * entry (e.g. `containerArgs.grid.column`). Placement edits are rarer than
   * typography edits, so we route directly through `replaceEntryContainerArgs`
   * (structural commit) rather than the keystroke-debounced `_pendingArgs`
   * pipeline used for `args`.
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
    const located = this._findEntryAndOutletSync(this.selectedBlockKey);
    if (!located) {
      return false;
    }
    return this._recordStructural([located.outletName], () => {
      const layout = this.readResolvedLayout(located.outletName);
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
      this._publishStructuralChange(located.outletName, result.layout);
      return true;
    });
  }

  /**
   * Applies every pending arg change in one shot by mutating the resolved
   * entry's `args` directly. The block's reactive getters propagate the
   * change through Glimmer's autotracking — no layout swap, no DOM
   * tear-down, no inspector remount.
   *
   * Captures the pre-edit snapshot BEFORE applying the mutation so reset /
   * exit / undo have the original state to restore. Records the affected
   * outlet in `_editedOutlets` so persistence knows what to POST on Save.
   *
   * @returns {Promise<boolean>} True if the flush touched an entry.
   */
  async _flushPendingArgs() {
    const key = this.selectedBlockKey;
    if (!key || this._pendingArgs.size === 0) {
      return false;
    }
    const pending = [...this._pendingArgs.entries()];
    this._pendingArgs.clear();

    const located = await this._findEntryAndOutlet(key);
    if (!located) {
      return false;
    }
    const { entry, outletName } = located;
    this._editedOutlets.add(outletName);

    const prev = new Map();
    for (const [argName] of pending) {
      prev.set(argName, entry.args?.[argName]);
    }

    // Capture the FULL pre-edit snapshot before applying mutations so
    // reset / exit have a complete picture of what to roll back to. Doing
    // this after the mutation would capture the post-edit state and make
    // rollback a no-op.
    this._captureInitialSnapshot(entry, prev);

    const next = new Map();
    for (const [argName, value] of pending) {
      next.set(argName, value);
      entry.args[argName] = value;
    }

    this._undoStack.push({ kind: "args", entry, prev, next });
    this._redoStack.length = 0;

    return true;
  }

  /**
   * Reverts the most recent mutation. For `args` batches, writes the
   * captured `prev` values back into `entry.args`. For `structural`
   * batches, re-publishes the captured `prevLayout` on each affected
   * outlet and restores the pre-mutation selection.
   *
   * @returns {Promise<boolean>}
   */
  @action
  async undo() {
    if (!this.canUndo) {
      return false;
    }
    const batch = this._undoStack.pop();
    if (batch.kind === "structural") {
      this._applyStructuralChanges(batch.changes, "prev");
      this._restoreSelection(batch.prevSelection);
    } else {
      this._writeArgs(batch.entry, batch.prev);
    }
    this._redoStack.push(batch);
    return true;
  }

  /**
   * Re-applies the most recently undone mutation. Mirror image of `undo()`.
   *
   * @returns {Promise<boolean>}
   */
  @action
  async redo() {
    if (!this.canRedo) {
      return false;
    }
    const batch = this._redoStack.pop();
    if (batch.kind === "structural") {
      this._applyStructuralChanges(batch.changes, "next");
      this._restoreSelection(batch.nextSelection);
    } else {
      this._writeArgs(batch.entry, batch.next);
    }
    this._undoStack.push(batch);
    return true;
  }

  /**
   * Captures a deep clone of `outletName`'s currently-resolved layout, or
   * `null` when the outlet has no published layout yet (the latter happens
   * when the editor is about to mint a fresh draft for an empty outlet).
   * Used as the before/after snapshot in structural undo entries.
   *
   * @param {string} outletName
   * @returns {Array<Object>|null}
   */
  _snapshotLayout(outletName) {
    const layout = this.readResolvedLayout(outletName);
    return layout ? cloneLayoutForDraft(layout) : null;
  }

  /**
   * Wraps a structural mutation so that it pushes an undo entry capturing
   * the pre/post layouts for every outlet it touches, plus the
   * pre/post selection. The caller passes the list of outlets that
   * `mutateFn` may write to; cross-outlet moves pass both source and
   * target so undo restores them in lockstep.
   *
   * If `mutateFn` returns a falsy value (i.e. the mutation no-op'd), no
   * undo entry is recorded and the falsy result propagates to the caller.
   *
   * @template T
   * @param {string[]} outletNames
   * @param {() => T} mutateFn
   * @returns {T}
   */
  _recordStructural(outletNames, mutateFn) {
    const prevLayouts = new Map();
    for (const name of outletNames) {
      prevLayouts.set(name, this._snapshotLayout(name));
    }
    const prevSelection = this.selectedBlockKey;
    const result = mutateFn();
    if (!result) {
      return result;
    }
    const changes = [];
    for (const [name, prevLayout] of prevLayouts) {
      changes.push({
        outletName: name,
        prevLayout,
        nextLayout: this._snapshotLayout(name),
      });
    }
    this._undoStack.push({
      kind: "structural",
      changes,
      prevSelection,
      nextSelection: this.selectedBlockKey,
    });
    this._redoStack.length = 0;
    return result;
  }

  /**
   * Republishes a list of `{outletName, prevLayout, nextLayout}` changes in
   * the given direction. When the target snapshot is `null` (i.e. the
   * outlet had no draft before the mutation), the SESSION_DRAFT layer is
   * cleared instead of re-published, restoring the resolved layout chain
   * to whatever lower layers (theme / code-default) carry.
   *
   * @param {Array<{outletName: string, prevLayout: Array<Object>|null, nextLayout: Array<Object>|null}>} changes
   * @param {"prev"|"next"} direction
   */
  _applyStructuralChanges(changes, direction) {
    for (const change of changes) {
      const layout =
        direction === "prev" ? change.prevLayout : change.nextLayout;
      if (layout == null) {
        _clearLayoutLayer(change.outletName, LAYOUT_LAYERS.SESSION_DRAFT);
        // The outlet returns to its un-drafted state — drop bookkeeping
        // so isDirty / save no longer flag it.
        this._draftedOutlets.delete(change.outletName);
        this._structurallyEditedOutlets.delete(change.outletName);
        this._editedOutlets.delete(change.outletName);
        continue;
      }
      _setLayoutLayer(
        change.outletName,
        LAYOUT_LAYERS.SESSION_DRAFT,
        cloneLayoutForDraft(layout),
        getOwner(this),
        { permissive: true }
      );
      this._draftedOutlets.add(change.outletName);
      this._editedOutlets.add(change.outletName);
      this._structurallyEditedOutlets.add(change.outletName);
    }
    this.structuralVersion++;
  }

  /**
   * Re-resolves the given block key against the current layout and rebinds
   * `selectedBlockKey` / `selectedBlockData`. If the key no longer exists,
   * clears the selection. Used after structural undo / redo to follow the
   * selection across layout snapshots.
   *
   * @param {string|null} blockKey
   */
  _restoreSelection(blockKey) {
    if (!blockKey) {
      this.selectBlock(null);
      return;
    }
    const located = this._findEntryAndOutletSync(blockKey);
    if (!located) {
      this.selectBlock(null);
      return;
    }
    const blockName = this._blockNameOf(located.entry);
    const metadata = blockName ? this._metadataForName(blockName) : null;
    this.selectBlock({
      key: blockKey,
      name: blockName,
      args: located.entry.args,
      metadata,
      outletName: located.outletName,
      conditions: located.entry.conditions ?? null,
    });
  }

  /**
   * Resolves an entry's block name. `entry.block` is either a class
   * reference (decorated blocks) or a string-ref (api.renderBlocks
   * factories) — this helper smooths over the two shapes.
   *
   * @param {Object} entry
   * @returns {string|null}
   */
  _blockNameOf(entry) {
    if (!entry?.block) {
      return null;
    }
    if (typeof entry.block === "string") {
      return entry.block;
    }
    return this._metadataFor(entry)?.blockName ?? null;
  }

  /**
   * Restores every touched outlet back to the pristine layout captured at
   * `enter()` (structural edits) and every touched entry back to its initial
   * (pre-edit) args (arg edits).
   *
   * For outlets that had structural mutations, we re-publish the captured
   * `_originalLayouts` clone — that's a fresh tree, so the draft layer's
   * entries get fully replaced. We then skip the per-entry args restoration
   * for those outlets because the new draft already carries pristine args
   * (the structurally-reset entries are the ones from `_originalLayouts`,
   * never mutated). Args-only outlets fall through to the existing
   * `_initialSnapshots` write-back path.
   *
   * @returns {Promise<boolean>}
   */
  @action
  async resetAll() {
    if (!this.isDirty) {
      return false;
    }

    // Wholesale re-publish of pristine layouts replaces every draft entry,
    // invalidating the per-entry references stored in `_initialSnapshots`
    // for those outlets — drop them so we don't try to mutate stale entries.
    const structurallyResetOutlets = new Set(this._structurallyEditedOutlets);
    if (structurallyResetOutlets.size > 0) {
      for (const outletName of structurallyResetOutlets) {
        const original = this._originalLayouts.get(outletName);
        if (!original) {
          continue;
        }
        // Clone again: the snapshot must remain pristine in case the user
        // mutates and then resets a second time during the same session.
        // Permissive matches the original publish in `_materializeAllDrafts`
        // — same session-draft layer, same tolerance contract.
        _setLayoutLayer(
          outletName,
          LAYOUT_LAYERS.SESSION_DRAFT,
          cloneLayoutForDraft(original),
          getOwner(this),
          { permissive: true }
        );
      }
      // Drop arg-snapshots whose entries belong to structurally-reset outlets.
      // Entries elsewhere keep their snapshots so the args path still works.
      for (const [entry] of this._initialSnapshots) {
        if (structurallyResetOutlets.has(this._outletForEntry(entry))) {
          this._initialSnapshots.delete(entry);
        }
      }
    }

    // Args-only restoration for whatever survived the structural pass.
    for (const [entry, snapshot] of this._initialSnapshots) {
      this._writeArgs(entry, snapshot);
    }
    this._undoStack.length = 0;
    this._redoStack.length = 0;
    this._initialSnapshots.clear();
    this._structurallyEditedOutlets.clear();
    this._editedOutlets.clear();
    return true;
  }

  /**
   * Best-effort lookup of the outlet name that owns `entry`. Walks the
   * currently-resolved layout map; returns null when the entry is no longer
   * present (e.g. it's been moved out of every published layer). Used by
   * `resetAll` to decide which arg-snapshots to drop after a structural
   * rollback.
   *
   * @param {Object} entry
   * @returns {string|null}
   */
  _outletForEntry(entry) {
    const layoutMap = _getOutletLayouts();
    for (const [outletName, record] of layoutMap) {
      if (record.layout && this._layoutContainsEntry(record.layout, entry)) {
        return outletName;
      }
    }
    return null;
  }

  _layoutContainsEntry(layout, target) {
    for (const entry of layout) {
      if (entry === target) {
        return true;
      }
      if (
        entry.children?.length &&
        this._layoutContainsEntry(entry.children, target)
      ) {
        return true;
      }
    }
    return false;
  }

  /**
   * Writes a `Map<argName, value>` of arg values into `entry.args`. Used by
   * undo, redo, and reset. Each assignment goes through the `trackedObject`
   * proxy so reactive readers re-evaluate.
   */
  _writeArgs(entry, args) {
    if (!entry?.args) {
      return;
    }
    for (const [argName, value] of args) {
      if (value === undefined) {
        delete entry.args[argName];
      } else {
        entry.args[argName] = value;
      }
    }
  }

  /**
   * Captures an entry's pre-edit args the FIRST time it's about to be
   * mutated, so `resetAll()` has a stable target regardless of how many
   * later edits we apply on top. Caller MUST invoke this BEFORE applying
   * the mutation — otherwise the snapshot captures the post-edit state.
   */
  _captureInitialSnapshot(entry, prev) {
    if (this._initialSnapshots.has(entry)) {
      return;
    }
    // Snapshot the entire pre-edit args object so reset is a true
    // round-trip even when later batches edit different keys. The `prev`
    // map is layered in for any keys it carries that aren't already in
    // the snapshot — defensive, since `prev` is built from `entry.args`
    // reads in the same critical section.
    const fullSnapshot = new Map();
    for (const [k, v] of Object.entries(entry.args ?? {})) {
      fullSnapshot.set(k, v);
    }
    for (const [k, v] of prev) {
      if (!fullSnapshot.has(k)) {
        fullSnapshot.set(k, v);
      }
    }
    this._initialSnapshots.set(entry, fullSnapshot);
  }

  /**
   * Walks every registered outlet's resolved layout looking for the entry
   * whose composite key matches. Returns the live entry plus its containing
   * outlet name so the caller can both mutate `entry.args` in place AND
   * tell persistence which outlet just got dirty.
   *
   * @param {string} key
   * @returns {Promise<{entry: Object, outletName: string}|null>}
   */
  async _findEntryAndOutlet(key) {
    const layoutMap = _getOutletLayouts();
    for (const [outletName, record] of layoutMap) {
      let layout;
      try {
        layout = await record.validatedLayout;
      } catch {
        continue;
      }
      const found = findEntry(layout, key);
      if (found) {
        return { entry: found, outletName };
      }
    }
    return null;
  }

  /**
   * Returns the resolved layout array for an outlet, or null when no layout
   * is registered. Used by the persistence service to grab the snapshot of
   * an edited outlet that needs to be POSTed.
   *
   * @param {string} outletName
   * @returns {Array<Object>|null}
   */
  readResolvedLayout(outletName) {
    return _getOutletLayouts().get(outletName)?.layout ?? null;
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
    this.dragSourceKey = blockKey;
    this.dragSourceOutlet = outletName;
    this.dragSource = {
      type: "ve-block",
      data: { blockKey, outletName },
    };
    document.body.classList.add("visual-editor-dragging");
  }

  /**
   * Records the start of a palette-driven drag. Mirrors `startDrag`
   * but with the `ve-palette-block` type so dragover-time consumers
   * can pick the right label / dispatch action. Called from
   * `PaletteEntry`'s `onDragStart`.
   *
   * @param {{blockName: string, defaultArgs: Object}} payload
   */
  @action
  startPaletteDrag({ blockName, defaultArgs }) {
    this.dragSource = {
      type: "ve-palette-block",
      data: { blockName, defaultArgs },
    };
    document.body.classList.add("visual-editor-dragging");
  }

  /**
   * Resets source-side drag state at the end of a drag (drop OR
   * cancellation — PDND's `draggable.onDrop` fires for both). This
   * deliberately does NOT clear `_lastDropPreview` / `activeDropPreview`:
   * PDND fires source `onDrop` BEFORE drop-target `onDrop` within the
   * same event, and our dispatch handlers (`dispatchActiveDrop`, plus
   * the native fallback path in `container-drop-target.js`) read those
   * fields. Clearing them here would race with dispatch.
   *
   * The dispatch-side state IS cleared, but by `dispatchActiveDrop`
   * itself once it has consumed the descriptor — that's the single
   * source of truth for those fields. For a cancelled drag (no drop
   * target was over the cursor), `_lastDropPreview` lingers harmlessly
   * until the next dragover overwrites it or a `clearActiveDropPreview`
   * fires from a dragleave.
   */
  @action
  endDrag() {
    this.dragSourceKey = null;
    this.dragSourceOutlet = null;
    this.dragSource = null;
    this.activeDropTarget = null;
    document.body.classList.remove("visual-editor-dragging");
  }

  /**
   * Writes the unified drop-preview descriptor. The mounted
   * `<DropPreview>` component reads `activeDropPreview` and paints
   * exactly one overlay; null hides it. Sources call this from
   * their dragover handlers; the `_lastDropPreview` mirror lets
   * drop-time dispatch read the same descriptor after the visible
   * one has been cleared.
   *
   * @param {Object|null} descriptor
   */
  @action
  setActiveDropPreview(descriptor) {
    this.activeDropPreview = descriptor;
    if (descriptor) {
      this._lastDropPreview = descriptor;
    }
  }

  /**
   * Hides the drop overlay (`activeDropPreview = null`) but keeps
   * `_lastDropPreview` populated for a tick so the drop handler
   * still has the descriptor to dispatch against.
   */
  @action
  clearActiveDropPreview() {
    this.activeDropPreview = null;
  }

  /**
   * Dispatches the operation described by `_lastDropPreview` (the
   * sticky mirror captured at the most recent dragover). The drop
   * handlers attached to container chromes / grid overlay call
   * this on `drop` — by then the visible preview may have been
   * cleared by a dragleave, but the dispatch payload is still
   * available here.
   *
   * Returns `true` when an operation ran; `false` when there was no
   * preview to dispatch against (e.g. dropped outside any
   * registered scope).
   *
   * @returns {boolean}
   */
  @action
  dispatchActiveDrop() {
    const preview = this._lastDropPreview;
    this._lastDropPreview = null;
    this.activeDropPreview = null;
    if (!preview?.dispatch) {
      return false;
    }
    const { action: actionName, args } = preview.dispatch;
    const method = this[actionName];
    if (typeof method !== "function") {
      return false;
    }
    method.call(this, args);
    return true;
  }

  /**
   * Highlights a drop zone as the dragged block hovers over it. The shell
   * reads `activeDropTarget` and applies a `--active` class to the matching
   * zone — keeps the per-zone modifier instances stateless.
   *
   * @param {{targetKey: string, position: string, outletName: string}} target
   */
  @action
  setActiveDropTarget(target) {
    this.activeDropTarget = target;
  }

  /**
   * Clears the active drop-zone highlight when the cursor leaves it. We
   * compare `targetKey` so a stale `dragLeave` from a zone we already moved
   * away from doesn't wipe the highlight on the *current* zone.
   *
   * @param {{targetKey: string, position: string}} target
   */
  @action
  clearActiveDropTarget(target) {
    if (
      this.activeDropTarget?.targetKey === target.targetKey &&
      this.activeDropTarget?.position === target.position
    ) {
      this.activeDropTarget = null;
    }
  }

  /**
   * @param {string} blockKey
   * @returns {boolean}
   */
  isForceExpanded(blockKey) {
    return blockKey ? this._forceExpandedKeys.has(blockKey) : false;
  }

  /**
   * Flips the force-expand state for a single `ve:layout` block. The
   * change is reactive — the chrome wrapper's class list re-renders
   * immediately to add or remove `--force-expanded`, and `GridOverlay`
   * sees an `isCollapsed` flip on its next dragover.
   *
   * @param {string} blockKey
   */
  @action
  toggleForceExpand(blockKey) {
    if (!blockKey) {
      return;
    }
    if (this._forceExpandedKeys.has(blockKey)) {
      this._forceExpandedKeys.delete(blockKey);
    } else {
      this._forceExpandedKeys.add(blockKey);
    }
  }

  /**
   * Resolves the metadata for a registered block by name. Returns null
   * for unknown names or when the registry entry is a factory the block
   * service hasn't materialised yet — same permissive contract as
   * `_metadataFor` for moves.
   *
   * @param {string} blockName
   * @returns {Object|null}
   */
  _metadataForName(blockName) {
    const klass = this.blocks.getBlock(blockName);
    if (!klass || typeof klass !== "function") {
      return null;
    }
    return getBlockMetadata(klass);
  }

  /**
   * Resolves a block reference (either a registry name string or
   * the decorated class itself, as it appears in layout entries)
   * to its canonical block name string. Returns `null` for
   * unresolvable references.
   *
   * @param {string|Function} blockRef
   * @returns {string|null}
   */
  _blockNameFor(blockRef) {
    if (typeof blockRef === "string") {
      return blockRef;
    }
    return getBlockMetadata(blockRef)?.blockName ?? null;
  }

  /**
   * Pulls the human-readable display name for a block from its
   * metadata. The drop-preview overlay uses this so labels match
   * the palette / outline vocabulary the author already sees
   * elsewhere. Falls back to the block name itself when no
   * display name is set.
   *
   * @param {string|Function} blockRef
   * @returns {string|null}
   */
  _lookupBlockDisplayName(blockRef) {
    const name = this._blockNameFor(blockRef);
    if (!name) {
      return null;
    }
    return this._metadataForName(name)?.displayName ?? name;
  }

  /**
   * Returns the block's metadata bag for any block-reference form
   * (string registry name or class). Convenience over picking
   * between `_metadataForName` (string) and `getBlockMetadata`
   * (class) at the call site.
   *
   * @param {string|Function} blockRef
   * @returns {Object|null}
   */
  _lookupBlockMetadata(blockRef) {
    if (typeof blockRef === "function") {
      return getBlockMetadata(blockRef) ?? null;
    }
    return this._metadataForName(blockRef);
  }

  /**
   * Tells whether inserting a fresh entry of `blockName` into
   * `targetOutletName` is compatible with the block class's outlet
   * restrictions. Same shape as `canDropAt` but for the insert path,
   * where there's no in-flight drag-source key to consult.
   *
   * @param {{blockName: string, targetOutletName: string}} target
   * @returns {boolean}
   */
  canInsertBlockAt({ blockName, targetOutletName }) {
    if (!blockName || !targetOutletName) {
      return false;
    }
    const metadata = this._metadataForName(blockName);
    if (!metadata) {
      // Unknown block — be permissive; the validator will catch it on save.
      return true;
    }
    if (metadata.deniedOutlets?.includes(targetOutletName)) {
      return false;
    }
    if (metadata.allowedOutlets?.length > 0) {
      return metadata.allowedOutlets.includes(targetOutletName);
    }
    return true;
  }

  /**
   * Tells whether dropping the currently-dragged block at `target` is
   * compatible with the system's authorization rules (`allowedOutlets` /
   * `deniedOutlets` declared on the block class). Same-outlet moves always
   * pass; cross-outlet moves consult the block's metadata.
   *
   * Returns true when no source key is set (no drag in progress) — keeps
   * `canDrop` calls cheap during normal operation.
   *
   * @param {{targetOutletName: string}} target
   * @returns {boolean}
   */
  canDropAt({ targetOutletName }) {
    if (!this.dragSourceKey) {
      return true;
    }
    if (!targetOutletName || targetOutletName === this.dragSourceOutlet) {
      return true;
    }
    const sourceEntry = this._findEntryByKey(this.dragSourceKey);
    if (!sourceEntry) {
      return false;
    }
    const metadata = this._metadataFor(sourceEntry);
    if (!metadata) {
      // No metadata = block class isn't registered. Be permissive — the
      // server-side validator will catch it on save if it really is broken.
      return true;
    }
    if (
      metadata.deniedOutlets &&
      metadata.deniedOutlets.includes(targetOutletName)
    ) {
      return false;
    }
    if (metadata.allowedOutlets?.length > 0) {
      return metadata.allowedOutlets.includes(targetOutletName);
    }
    return true;
  }

  /**
   * Moves the entry identified by `sourceKey` to a new position in the
   * layout, applying the mutation to the relevant draft layer(s) and
   * recording the affected outlets so the toolbar's `isDirty`/Save and
   * `resetAll` paths pick the change up.
   *
   * Same-outlet moves are a single immutable rebuild via `moveEntry`.
   * Cross-outlet moves split into `removeEntry` from the source outlet and
   * `insertEntryAt` on the target. Both paths re-publish via
   * `_setLayoutLayer`, which preserves entry references where possible —
   * the dragged block keeps its arg edits across the move.
   *
   * Returns true on a successful structural change. Returns false (and
   * leaves layouts untouched) when the source/target can't be located, the
   * block isn't allowed in the target outlet, or the move would create a
   * self-nesting cycle (handled inside `moveEntry`).
   *
   * @param {{
   *   sourceKey: string,
   *   targetKey: string|null,
   *   position: "before"|"after"|"inside",
   *   targetOutletName: string,
   * }} args
   * @returns {boolean}
   */
  @action
  moveBlock({ sourceKey, targetKey, position, targetOutletName }) {
    const source = this._findEntryAndOutletSync(sourceKey);
    if (!source) {
      return false;
    }
    if (!this.canDropAt({ targetOutletName })) {
      return false;
    }
    const outletsAffected =
      source.outletName === targetOutletName
        ? [source.outletName]
        : [source.outletName, targetOutletName];
    return this._recordStructural(outletsAffected, () => {
      if (source.outletName === targetOutletName) {
        return this._moveWithinOutlet(
          source.outletName,
          sourceKey,
          targetKey,
          position
        );
      }
      return this._moveAcrossOutlets({
        sourceOutletName: source.outletName,
        targetOutletName,
        sourceEntry: source.entry,
        sourceKey,
        targetKey,
        position,
      });
    });
  }

  /**
   * Inserts a freshly-synthesised entry at the given position in the
   * target outlet. Mirrors `moveBlock`'s shape but takes a `blockName`
   * (and a defaultArgs payload from the palette) instead of a source key,
   * since there's no existing entry to lift from elsewhere.
   *
   * The new entry is minted as a plain `{block: blockName, args}` POJO;
   * `assignStableKeys` (invoked by `_setLayoutLayer` inside
   * `_publishStructuralChange`) stamps a `__stableKey` when the draft
   * layer is published, so the rest of the editor (selection, drag,
   * outline) can address it by key from the next render onwards.
   *
   * Returns false (and leaves the layout untouched) when the target
   * outlet doesn't have a resolvable layout, the block isn't allowed in
   * that outlet, or the insert otherwise no-ops.
   *
   * @param {{
   *   blockName: string,
   *   defaultArgs?: Object,
   *   targetKey: string|null,
   *   position: "before"|"after"|"inside",
   *   targetOutletName: string,
   * }} args
   * @returns {boolean}
   */
  @action
  insertBlock({
    blockName,
    defaultArgs = {},
    targetKey,
    position,
    targetOutletName,
  }) {
    if (!this.canInsertBlockAt({ blockName, targetOutletName })) {
      return false;
    }
    return this._recordStructural([targetOutletName], () => {
      // Mint a draft on the fly for outlets the user is populating from
      // scratch (no published layout → `_materializeAllDrafts` skipped
      // them on `enter()`). The empty-outlet drop zone needs this.
      const layout = this._ensureDraft(targetOutletName);
      if (!layout) {
        return false;
      }
      // Mint a fresh entry. Spread the defaults so future mutations don't
      // bleed back into the palette's `previewArgs` object.
      const fresh = { block: blockName, args: { ...defaultArgs } };
      // Annotate with `containerArgs.grid` defaults when the destination
      // parent is a `ve:layout` in grid mode — that's the placement
      // namespace the grid layout reads to position each direct child.
      const entry = this._annotateForDestination({
        entry: fresh,
        layout,
        targetKey,
        position,
      });
      const insertion = insertEntryAt(layout, targetKey, entry, position);
      if (!insertion.changed) {
        return false;
      }
      this._publishStructuralChange(targetOutletName, insertion.layout);
      // Auto-select the freshly inserted block so the inspector immediately
      // shows its form (and, for a `ve:layout` in grid mode, the grid overlay
      // mounts without the author having to click first).
      // `_publishStructuralChange` runs `assignStableKeys`, so `entry`
      // has a `__stableKey` by the time this fires.
      this._selectInsertedEntry(entry);
      return true;
    });
  }

  /**
   * Looks up the composite key of a freshly inserted entry (after
   * `_publishStructuralChange` has assigned its `__stableKey`) and routes
   * through `_restoreSelection` so the editor's selection state — and the
   * inspector — points at it. No-ops if the entry isn't yet resolvable
   * (paranoia: the assign should always succeed for a just-inserted entry).
   *
   * @param {Object} entry - The original entry reference passed into the
   *   layout; will have its `__stableKey` set by the publish step.
   */
  _selectInsertedEntry(entry) {
    const key = entryKey(entry);
    if (!key) {
      return;
    }
    this._restoreSelection(key);
  }

  /**
   * Updates the `column` / `row` placement of a grid-cell entry. Used by
   * the grid overlay's pointer-drag handlers to commit a new placement
   * on drop.
   *
   * Routes through `_recordStructural` so the placement change rides
   * the same Cmd+Z stack as inserts and removes — undoing a drag
   * reverts the tile to its previous cell.
   *
   * @param {{slotKey: string, column: string, row: string}} args
   * @returns {boolean}
   */
  @action
  setSlotPlacement({ slotKey, column, row }) {
    const located = this._findEntryAndOutletSync(slotKey);
    if (!located || !this._isGridCellEntry(located.entry)) {
      return false;
    }
    return this._recordStructural([located.outletName], () => {
      const layout = this.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const result = replaceEntryContainerArgs(
        layout,
        slotKey,
        "grid",
        (current) => ({ ...current, column, row })
      );
      if (!result.changed) {
        return false;
      }
      this._publishStructuralChange(located.outletName, result.layout);
      return true;
    });
  }

  /**
   * Swaps the `column` / `row` args of two slots in the same grid. One
   * `_recordStructural` entry so swap-then-undo restores both placements
   * atomically.
   *
   * @param {{slotKeyA: string, slotKeyB: string}} args
   * @returns {boolean}
   */
  @action
  swapSlotPlacements({ slotKeyA, slotKeyB }) {
    if (!slotKeyA || !slotKeyB || slotKeyA === slotKeyB) {
      return false;
    }
    const a = this._findEntryAndOutletSync(slotKeyA);
    const b = this._findEntryAndOutletSync(slotKeyB);
    if (!a || !b || a.outletName !== b.outletName) {
      return false;
    }
    if (!this._isGridCellEntry(a.entry) || !this._isGridCellEntry(b.entry)) {
      return false;
    }
    const aGrid = {
      column: a.entry.containerArgs?.grid?.column ?? "auto",
      row: a.entry.containerArgs?.grid?.row ?? "auto",
    };
    const bGrid = {
      column: b.entry.containerArgs?.grid?.column ?? "auto",
      row: b.entry.containerArgs?.grid?.row ?? "auto",
    };
    return this._recordStructural([a.outletName], () => {
      let layout = this.readResolvedLayout(a.outletName);
      const firstSwap = replaceEntryContainerArgs(
        layout,
        slotKeyA,
        "grid",
        (current) => ({ ...current, column: bGrid.column, row: bGrid.row })
      );
      if (!firstSwap.changed) {
        return false;
      }
      layout = firstSwap.layout;
      const secondSwap = replaceEntryContainerArgs(
        layout,
        slotKeyB,
        "grid",
        (current) => ({ ...current, column: aGrid.column, row: aGrid.row })
      );
      if (!secondSwap.changed) {
        return false;
      }
      this._publishStructuralChange(a.outletName, secondSwap.layout);
      return true;
    });
  }

  /**
   * Removes the target grid cell occupant and re-places the source
   * cell at the target's old `column` / `row` — atomically, under one
   * structural-undo entry. Used for the Shift-held "replace" gesture:
   * target dies, source takes its cell.
   *
   * Both entries must live in the same outlet and both must be grid
   * cell occupants (i.e. the source drag came from a grid block, not
   * a palette).
   *
   * @param {{targetSlotKey: string, sourceSlotKey: string}} args
   * @returns {boolean}
   */
  @action
  replaceSlot({ targetSlotKey, sourceSlotKey }) {
    if (!targetSlotKey || !sourceSlotKey || targetSlotKey === sourceSlotKey) {
      return false;
    }
    const target = this._findEntryAndOutletSync(targetSlotKey);
    const source = this._findEntryAndOutletSync(sourceSlotKey);
    if (
      !target ||
      !source ||
      target.outletName !== source.outletName ||
      !this._isGridCellEntry(target.entry) ||
      !this._isGridCellEntry(source.entry)
    ) {
      return false;
    }
    const targetCol = target.entry.containerArgs?.grid?.column ?? "auto";
    const targetRow = target.entry.containerArgs?.grid?.row ?? "auto";
    return this._recordStructural([target.outletName], () => {
      let layout = this.readResolvedLayout(target.outletName);
      const removal = removeEntry(layout, targetSlotKey);
      if (!removal.changed) {
        return false;
      }
      layout = removal.layout;
      const moved = replaceEntryContainerArgs(
        layout,
        sourceSlotKey,
        "grid",
        (current) => ({ ...current, column: targetCol, row: targetRow })
      );
      if (!moved.changed) {
        return false;
      }
      this._publishStructuralChange(target.outletName, moved.layout);
      return true;
    });
  }

  /**
   * Inserts a new block at the edge of `dropSlotKey`, cascading existing
   * slots in the appropriate direction to make room. Wraps the entire
   * sequence (cascade + insert) into one structural-undo entry.
   *
   * The source can be:
   *  - an existing slot in this grid (`sourceKey` set, `paletteBlockName`
   *    null) — its cell is freed during planning so it can absorb the
   *    cascade tail (enables rotations like `A, B, C → C, A, B`).
   *  - a fresh palette block (`sourceKey` null, `paletteBlockName` /
   *    `paletteDefaultArgs` set) — a new slot is minted at the landing
   *    cell with the named block inside.
   *  - a slot from another grid or container — wrapped/unwrapped via
   *    the existing `_transformForDestination` path, then re-targeted
   *    to the landing cell.
   *
   * Returns false (no commit) when the shift plan is invalid (cascade
   * runs off-grid, or shifted slots would overlap a span).
   *
   * @param {{
   *   gridKey: string,
   *   dropSlotKey: string,
   *   direction: "left"|"right"|"up"|"down",
   *   sourceKey: string|null,
   *   paletteBlockName: string|null,
   *   paletteDefaultArgs: Object|null,
   * }} args
   * @returns {boolean}
   */
  @action
  insertWithShift({
    gridKey,
    dropSlotKey = null,
    dropCell = null,
    direction,
    sourceKey = null,
    paletteBlockName = null,
    paletteDefaultArgs = null,
  }) {
    const grid = this._findEntryAndOutletSync(gridKey);
    if (!grid || !this._isGridContainer(grid.entry)) {
      return false;
    }
    const sourceLocated = sourceKey
      ? this._findEntryAndOutletSync(sourceKey)
      : null;
    // Resolve the "source-in-this-grid" key for computeShiftPlan's
    // free-cell credit. Only same-grid sources free a cell; cross-grid
    // sources count as new arrivals.
    const sourceInGrid =
      sourceLocated &&
      sourceLocated.outletName === grid.outletName &&
      this._isCellInGrid(sourceLocated.entry, gridKey)
        ? sourceKey
        : null;
    const plan = computeShiftPlan({
      slots: grid.entry.children ?? [],
      sourceKey: sourceInGrid,
      dropSlotKey,
      dropCell,
      direction,
      gridDims: {
        columns: Number(grid.entry.args?.columns ?? 6),
        rows: Number(grid.entry.args?.rows ?? 2),
      },
    });
    if (!plan) {
      return false;
    }
    const outletsAffected =
      sourceLocated && sourceLocated.outletName !== grid.outletName
        ? [sourceLocated.outletName, grid.outletName]
        : [grid.outletName];
    return this._recordStructural(outletsAffected, () => {
      // Apply the cascade first so subsequent inserts / placements
      // see the post-shift occupancy.
      for (const move of plan.moves) {
        const layout = this.readResolvedLayout(grid.outletName);
        const result = replaceEntryContainerArgs(
          layout,
          move.slotKey,
          "grid",
          (current) => ({ ...current, column: move.column, row: move.row })
        );
        if (!result.changed) {
          return false;
        }
        this._publishStructuralChange(grid.outletName, result.layout);
      }
      // Now place the source at the landing cell.
      const { column, row } = plan.sourceLanding;
      if (sourceKey && sourceInGrid) {
        // Same-grid existing cell: just re-place it.
        const layout = this.readResolvedLayout(grid.outletName);
        const result = replaceEntryContainerArgs(
          layout,
          sourceKey,
          "grid",
          (current) => ({ ...current, column, row })
        );
        if (!result.changed) {
          return false;
        }
        this._publishStructuralChange(grid.outletName, result.layout);
      } else if (sourceKey) {
        // Cross-container source: move it into the target grid, then
        // re-place at the landing cell. The move preserves the entry's
        // identity (annotate-in-place rather than wrap/unwrap), so we
        // can re-target the SAME source key after the move.
        const moved = this._moveAcrossOutlets({
          sourceOutletName: sourceLocated.outletName,
          targetOutletName: grid.outletName,
          sourceKey,
          targetKey: gridKey,
          position: "inside",
        });
        if (!moved) {
          return false;
        }
        const layout = this.readResolvedLayout(grid.outletName);
        const result = replaceEntryContainerArgs(
          layout,
          sourceKey,
          "grid",
          (current) => ({ ...current, column, row })
        );
        if (result.changed) {
          this._publishStructuralChange(grid.outletName, result.layout);
        }
      } else if (paletteBlockName) {
        // Palette drop: mint a fresh cell occupant at the landing cell.
        const layout = this.readResolvedLayout(grid.outletName);
        if (!layout) {
          return false;
        }
        const cellEntry = {
          block: paletteBlockName,
          args: { ...(paletteDefaultArgs ?? {}) },
          containerArgs: {
            grid: { column, row, align: "stretch", justify: "stretch" },
          },
        };
        const insertion = insertEntryAt(layout, gridKey, cellEntry, "inside");
        if (!insertion.changed) {
          return false;
        }
        this._publishStructuralChange(grid.outletName, insertion.layout);
        this._selectInsertedEntry(cellEntry);
      } else {
        return false;
      }
      return true;
    });
  }

  /**
   * Whether `entry` is a grid-cell occupant whose direct parent is the
   * layout identified by `gridKey`. Used by `insertWithShift` to decide
   * whether to credit the source's cell as free during planning.
   *
   * @param {Object} entry
   * @param {string} gridKey
   * @returns {boolean}
   */
  _isCellInGrid(entry, gridKey) {
    if (!this._isGridCellEntry(entry)) {
      return false;
    }
    const parent = this._findEntryParent(entryKey(entry));
    return parent && entryKey(parent) === gridKey;
  }

  /**
   * Returns the slot children of a grid `ve:layout` whose explicit
   * column / row placements would fall outside the given bounds. Each
   * entry yields the slot's composite key and the offending placement
   * for diagnostic / clamping callers.
   *
   * Auto-placed slots (no explicit column / row) are excluded — CSS
   * Grid auto-flow handles them regardless of the bounds change.
   *
   * @param {string} gridKey
   * @param {number} maxColumns
   * @param {number} maxRows
   * @returns {Array<{slotKey: string, column: string, row: string}>}
   */
  outOfBoundsSlotsIn(gridKey, maxColumns, maxRows) {
    const located = this._findEntryAndOutletSync(gridKey);
    if (!located || !this._isGridContainer(located.entry)) {
      return [];
    }
    const offenders = [];
    for (const slot of located.entry.children ?? []) {
      if (!this._isGridCellEntry(slot)) {
        continue;
      }
      const placement = parsePlacement(slot.containerArgs);
      const colExceeds =
        placement.column.start != null &&
        placement.column.end != null &&
        placement.column.end > maxColumns + 1;
      const rowExceeds =
        placement.row.start != null &&
        placement.row.end != null &&
        placement.row.end > maxRows + 1;
      if (colExceeds || rowExceeds) {
        offenders.push({
          slotKey: entryKey(slot),
          column: slot.containerArgs?.grid?.column ?? "auto",
          row: slot.containerArgs?.grid?.row ?? "auto",
        });
      }
    }
    return offenders;
  }

  /**
   * Clamps every slot in a grid layout so its placement fits inside
   * the given bounds. Slots whose end lines exceed the new max get
   * their spans truncated; slots whose start lines exceed it get
   * snapped back to the last valid cell with span 1.
   *
   * Runs as a single structural-undo entry so the whole clamp can be
   * reverted with one Cmd+Z (e.g. after a "Reduce columns" confirm).
   *
   * @param {{gridKey: string, maxColumns: number, maxRows: number}} args
   * @returns {boolean}
   */
  @action
  clampGridSlotPlacements({ gridKey, maxColumns, maxRows }) {
    const located = this._findEntryAndOutletSync(gridKey);
    if (!located || !this._isGridContainer(located.entry)) {
      return false;
    }
    const offenders = this.outOfBoundsSlotsIn(gridKey, maxColumns, maxRows);
    if (offenders.length === 0) {
      return false;
    }
    return this._recordStructural([located.outletName], () => {
      for (const slot of located.entry.children ?? []) {
        if (!this._isGridCellEntry(slot)) {
          continue;
        }
        const placement = parsePlacement(slot.containerArgs);
        const newColumn = this._clampTrack(placement.column, maxColumns);
        const newRow = this._clampTrack(placement.row, maxRows);
        if (newColumn == null && newRow == null) {
          continue;
        }
        const layout = this.readResolvedLayout(located.outletName);
        const result = replaceEntryContainerArgs(
          layout,
          entryKey(slot),
          "grid",
          (current) => ({
            ...current,
            ...(newColumn != null && { column: newColumn }),
            ...(newRow != null && { row: newRow }),
          })
        );
        if (!result.changed) {
          continue;
        }
        this._publishStructuralChange(located.outletName, result.layout);
      }
      return true;
    });
  }

  /**
   * Returns a clamped CSS Grid track shorthand, or `null` if the track
   * is already within bounds (so callers can skip writing it). Auto
   * placements pass through unchanged.
   *
   * @param {{start: number|null, end: number|null}} track
   * @param {number} max
   * @returns {string|null}
   */
  _clampTrack(track, max) {
    if (track.start == null) {
      return null;
    }
    const lastLine = max + 1;
    const start = Math.min(track.start, max);
    const end = track.end == null ? start + 1 : Math.min(track.end, lastLine);
    const safeEnd = Math.max(end, start + 1);
    if (start === track.start && safeEnd === track.end) {
      return null;
    }
    return safeEnd <= start + 1 ? `${start}` : `${start} / ${safeEnd}`;
  }

  /**
   * Locates the immediate parent entry of `blockKey` by walking the
   * resolved layout. Returns `null` when the key isn't found or when
   * the entry sits at the outlet root (no block-level parent).
   *
   * Used by chrome decoration to determine context — e.g. showing a
   * resize handle only when the block sits inside a grid layout.
   *
   * @param {string} blockKey
   * @returns {Object|null}
   */
  _findEntryParent(blockKey) {
    const located = this._findEntryAndOutletSync(blockKey);
    if (!located) {
      return null;
    }
    const layout = this.readResolvedLayout(located.outletName);
    if (!layout) {
      return null;
    }
    const path = findAncestryPath(layout, blockKey);
    if (!path || path.length < 2) {
      return null;
    }
    return path[path.length - 2];
  }

  /**
   * Returns `true` when `ancestorKey` appears in `descendantKey`'s
   * ancestry path. Used by chrome decoration to keep the grid overlay
   * mounted while the user is editing one of the layout's children
   * (the layout itself stops being `selectedBlockKey` once the user
   * clicks into a cell, but the overlay should stay visible until they
   * navigate fully away).
   *
   * @param {string} ancestorKey
   * @param {string} descendantKey
   * @returns {boolean}
   */
  _isAncestorOf(ancestorKey, descendantKey) {
    if (!ancestorKey || !descendantKey || ancestorKey === descendantKey) {
      return false;
    }
    const located = this._findEntryAndOutletSync(descendantKey);
    if (!located) {
      return false;
    }
    const layout = this.readResolvedLayout(located.outletName);
    if (!layout) {
      return false;
    }
    const path = findAncestryPath(layout, descendantKey);
    if (!path) {
      return false;
    }
    return path.some((entry) => entryKey(entry) === ancestorKey);
  }

  /**
   * Moves an existing block to a specific cell of a grid layout.
   *
   * Two cases:
   *  - Source already lives directly inside the target grid → update
   *    its `containerArgs.grid.column / .row` via `setSlotPlacement`.
   *  - Cross-container source → move it into the grid (which annotates
   *    `containerArgs.grid` with `auto / auto`), then re-target the
   *    same entry's placement to the requested cell.
   *
   * @param {{
   *   gridKey: string,
   *   sourceKey: string,
   *   column: number,
   *   row: number,
   * }} args
   * @returns {boolean}
   */
  @action
  moveBlockToCell({ gridKey, sourceKey, column, row }) {
    const grid = this._findEntryAndOutletSync(gridKey);
    if (!grid || !this._isGridContainer(grid.entry)) {
      return false;
    }
    const sourceLocated = this._findEntryAndOutletSync(sourceKey);
    if (!sourceLocated) {
      return false;
    }
    const sourceParent = this._findEntryParent(sourceKey);
    const sourceParentKey = sourceParent ? entryKey(sourceParent) : null;

    // Same-grid source: the entry IS the cell occupant. Update placement.
    if (
      this._isGridCellEntry(sourceLocated.entry) &&
      sourceParentKey === gridKey
    ) {
      return this.setSlotPlacement({
        slotKey: sourceKey,
        column: `${column}`,
        row: `${row}`,
      });
    }

    // Cross-container case: move into the grid + apply the cell placement
    // as ONE structural-undo entry so a single Cmd+Z reverts the whole
    // drag, not just the placement. The move now preserves entry
    // identity (annotate-in-place via `_transformForDestination`), so we
    // re-target the same `sourceKey` afterward.
    const outletsAffected =
      sourceLocated.outletName === grid.outletName
        ? [grid.outletName]
        : [sourceLocated.outletName, grid.outletName];

    return this._recordStructural(outletsAffected, () => {
      // Call the inner movers directly to avoid the nested
      // `_recordStructural` that `moveBlock` would impose.
      const moved =
        sourceLocated.outletName === grid.outletName
          ? this._moveWithinOutlet(
              grid.outletName,
              sourceKey,
              gridKey,
              "inside"
            )
          : this._moveAcrossOutlets({
              sourceOutletName: sourceLocated.outletName,
              targetOutletName: grid.outletName,
              sourceKey,
              targetKey: gridKey,
              position: "inside",
            });
      if (!moved) {
        return false;
      }
      const updatedLayout = this.readResolvedLayout(grid.outletName);
      const result = replaceEntryContainerArgs(
        updatedLayout,
        sourceKey,
        "grid",
        (current) => ({
          ...current,
          column: `${column}`,
          row: `${row}`,
        })
      );
      if (result.changed) {
        this._publishStructuralChange(grid.outletName, result.layout);
      }
      return true;
    });
  }

  @action
  insertBlockAtCell({ gridKey, blockName, defaultArgs = {}, column, row }) {
    const located = this._findEntryAndOutletSync(gridKey);
    if (!located || !this._isGridContainer(located.entry)) {
      return false;
    }
    if (
      !this.canInsertBlockAt({
        blockName,
        targetOutletName: located.outletName,
      })
    ) {
      return false;
    }
    return this._recordStructural([located.outletName], () => {
      const layout = this.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const cellEntry = {
        block: blockName,
        args: { ...defaultArgs },
        containerArgs: {
          grid: {
            column: `${column}`,
            row: `${row}`,
            align: "stretch",
            justify: "stretch",
          },
        },
      };
      // Insert as the first child of the grid. CSS Grid honours the
      // explicit column / row regardless of DOM order.
      const insertion = insertEntryAt(layout, gridKey, cellEntry, "inside");
      if (!insertion.changed) {
        return false;
      }
      this._publishStructuralChange(located.outletName, insertion.layout);
      // Auto-select the new cell so the inspector immediately shows its
      // content args (and the placement section for the parent grid's
      // childArgs schema).
      this._selectInsertedEntry(cellEntry);
      return true;
    });
  }

  /**
   * Applies a preset grid template to an existing `ve:layout` block.
   * The template's `areas` string is parsed into `{columns, rows,
   * slots}`; each slot becomes a `ve:slot` entry positioned at its
   * rect.
   *
   * Apply algorithm:
   *
   *  - **Frame-only template** (no `areas`, e.g. "12-column"): write
   *    the frame args, leave existing children alone. The author may
   *    end up with out-of-bounds placements; that's handled by the
   *    existing `--out-of-bounds` warning + "Snap blocks into bounds"
   *    fix.
   *  - **Template with `s` slots, existing child count `n`**:
   *    - `n === 0`: insert the slot entries as children, apply silently.
   *    - `0 < n ≤ s`: preserve existing children, fit them into the
   *      first `n` slots in document order — each child's
   *      `containerArgs.grid` is overwritten with the slot's rect.
   *      Append `ve:slot` entries for the remaining `(s - n)` slots.
   *    - `n > s`: refuse. Returns `false` so the inspector can disable
   *      the chip with a "more blocks than cells" tooltip.
   *
   * Wrapped in a single structural-undo entry so the whole switch
   * can be reverted with one Cmd+Z.
   *
   * @param {{gridKey: string, template: Object}} args
   * @returns {boolean}
   */
  @action
  applyGridTemplate({ gridKey, template }) {
    if (!template) {
      return false;
    }
    const located = this._findEntryAndOutletSync(gridKey);
    if (!located) {
      return false;
    }
    const { args: templateArgs, slotEntries } = resolveTemplateLayout(template);
    const existingChildren = located.entry.children ?? [];
    // n > s: refuse before mutating anything.
    if (
      slotEntries.length > 0 &&
      existingChildren.length > slotEntries.length
    ) {
      return false;
    }
    return this._recordStructural([located.outletName], () => {
      const layout = this.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      let nextChildren;
      if (slotEntries.length === 0) {
        // Frame-only — leave children alone.
        nextChildren = located.entry.children;
      } else {
        // Pair each existing child with a slot (document order), then
        // pad with empty `ve:slot` entries for the leftover slots.
        // Each paired child gets the slot's rect on its
        // `containerArgs.grid`, overwriting whatever was there.
        nextChildren = slotEntries.map((slotEntry, i) => {
          const existing = existingChildren[i];
          if (existing) {
            return {
              ...existing,
              containerArgs: {
                ...existing.containerArgs,
                grid: { ...slotEntry.containerArgs.grid },
              },
            };
          }
          return slotEntry;
        });
      }
      const result = replaceEntryInPlace(layout, gridKey, {
        ...located.entry,
        args: { ...located.entry.args, ...templateArgs },
        children: nextChildren,
      });
      if (!result.changed) {
        return false;
      }
      this._publishStructuralChange(located.outletName, result.layout);
      return true;
    });
  }

  /**
   * Returns `true` when `applyGridTemplate` would succeed for the
   * given template against the currently-selected `ve:layout`.
   * Pure-read; the inspector calls this to enable / disable each
   * template chip (a chip is disabled when the template can't fit
   * the current content). Mirrors the refusal predicate inside
   * `applyGridTemplate` itself.
   *
   * @param {{gridKey: string, template: Object}} args
   * @returns {boolean}
   */
  canApplyGridTemplate({ gridKey, template }) {
    if (!template) {
      return false;
    }
    const located = this._findEntryAndOutletSync(gridKey);
    if (!located) {
      return false;
    }
    const { slotEntries } = resolveTemplateLayout(template);
    if (slotEntries.length === 0) {
      // Frame-only templates always apply.
      return true;
    }
    const existing = located.entry.children?.length ?? 0;
    return existing <= slotEntries.length;
  }

  /**
   * Moves a canvas block onto a `ve:slot`, removing the source and
   * replacing the slot with the moved block's data — the moved
   * block adopts the slot's `containerArgs.grid` so it lands at the
   * slot's rect. Same-outlet only for now; cross-outlet move-into-slot
   * is a future iteration.
   *
   * @param {{sourceKey: string, slotKey: string}} args
   * @returns {boolean}
   */
  @action
  moveBlockIntoSlot({ sourceKey, slotKey }) {
    if (sourceKey === slotKey) {
      return false;
    }
    const sourceLocated = this._findEntryAndOutletSync(sourceKey);
    const slotLocated = this._findEntryAndOutletSync(slotKey);
    if (!sourceLocated || !slotLocated) {
      return false;
    }
    if (sourceLocated.outletName !== slotLocated.outletName) {
      return false;
    }
    if (slotLocated.entry.block !== "ve:slot") {
      return false;
    }
    return this._recordStructural([slotLocated.outletName], () => {
      const layout = this.readResolvedLayout(slotLocated.outletName);
      if (!layout) {
        return false;
      }
      const removal = removeEntry(layout, sourceKey);
      if (!removal.changed || !removal.removed) {
        return false;
      }
      // Drop the source's `__stableKey` — the slot's stableKey wins
      // (`replaceEntryInPlace` preserves the matched entry's stableKey
      // on the swap), which is the right identity for re-render
      // continuity at the slot's position.
      const { __stableKey, ...sourceData } = removal.removed;
      void __stableKey;
      const movedEntry = {
        ...sourceData,
        containerArgs: slotLocated.entry.containerArgs,
      };
      const replacement = replaceEntryInPlace(
        removal.layout,
        slotKey,
        movedEntry
      );
      if (!replacement.changed) {
        return false;
      }
      this._publishStructuralChange(slotLocated.outletName, replacement.layout);
      return true;
    });
  }

  /**
   * Replaces a `ve:slot` entry with a real block. The new entry
   * inherits the slot's `containerArgs.grid` so it lands at the
   * same rect; CSS Grid then places the rendered block exactly
   * where the slot was.
   *
   * @param {{slotKey: string, blockName: string, defaultArgs?: Object}} args
   * @returns {boolean}
   */
  @action
  fillSlot({ slotKey, blockName, defaultArgs = {} }) {
    const located = this._findEntryAndOutletSync(slotKey);
    if (!located || located.entry.block !== "ve:slot") {
      return false;
    }
    if (
      !this.canInsertBlockAt({
        blockName,
        targetOutletName: located.outletName,
      })
    ) {
      return false;
    }
    return this._recordStructural([located.outletName], () => {
      const layout = this.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const newEntry = {
        block: blockName,
        args: { ...defaultArgs },
        containerArgs: located.entry.containerArgs,
      };
      const result = replaceEntryInPlace(layout, slotKey, newEntry);
      if (!result.changed) {
        return false;
      }
      this._publishStructuralChange(located.outletName, result.layout);
      this._selectInsertedEntry(newEntry);
      return true;
    });
  }

  _moveWithinOutlet(outletName, sourceKey, targetKey, position) {
    const layout = this.readResolvedLayout(outletName);
    if (!layout) {
      return false;
    }
    const sourceEntry = findEntry(layout, sourceKey);
    if (!sourceEntry) {
      return false;
    }
    // Same-outlet move: the destination may require wrapping (non-slot
    // entering a grid) OR unwrapping (slot leaving a grid). Both cases
    // substitute the entry — moveEntry preserves identity, so a
    // remove+insert is needed when the shape changes.
    const transformed = this._transformForDestination({
      entry: sourceEntry,
      layout,
      targetKey,
      position,
    });
    if (transformed !== sourceEntry) {
      const removal = removeEntry(layout, sourceKey);
      if (!removal.changed || !removal.removed) {
        return false;
      }
      // For wrap, the transform already built the slot wrapper around
      // `sourceEntry` — but `removal.removed` is the same reference,
      // so the wrapper's inner child is still correct.
      // For unwrap, the transform returned the inner block directly,
      // which is also referentially correct.
      const insertion = insertEntryAt(
        removal.layout,
        targetKey,
        transformed,
        position
      );
      if (!insertion.changed) {
        return false;
      }
      this._publishStructuralChange(outletName, insertion.layout);
      return true;
    }
    const result = moveEntry(layout, sourceKey, targetKey, position);
    if (!result.changed) {
      return false;
    }
    this._publishStructuralChange(outletName, result.layout);
    return true;
  }

  _moveAcrossOutlets({
    sourceOutletName,
    targetOutletName,
    sourceKey,
    targetKey,
    position,
  }) {
    const sourceLayout = this.readResolvedLayout(sourceOutletName);
    // Mint a draft for the target outlet if it doesn't have one yet —
    // the user may be dragging an existing block into a previously
    // empty outlet (via the empty-outlet drop zone from Phase 7p.1).
    const targetLayout = this._ensureDraft(targetOutletName);
    if (!sourceLayout || !targetLayout) {
      return false;
    }
    const removal = removeEntry(sourceLayout, sourceKey);
    if (!removal.changed || !removal.removed) {
      return false;
    }
    // The moved entry may need to be wrapped (non-slot landing in a
    // grid) OR unwrapped (slot landing in a non-grid). Both cases
    // funnel through `_transformForDestination`.
    const entryToInsert = this._transformForDestination({
      entry: removal.removed,
      layout: targetLayout,
      targetKey,
      position,
    });
    const insertion = insertEntryAt(
      targetLayout,
      targetKey,
      entryToInsert,
      position
    );
    if (!insertion.changed) {
      return false;
    }
    // Publish both outlets in one go — the editor service holds both as
    // session-draft layers, so each `_setLayoutLayer` call only re-resolves
    // its own outlet's chain.
    this._publishStructuralChange(sourceOutletName, removal.layout);
    this._publishStructuralChange(targetOutletName, insertion.layout);
    return true;
  }

  /**
   * Annotates an entry with `containerArgs.grid` defaults when its
   * destination parent is a `ve:layout` in `grid` mode. The grid
   * namespace carries CSS Grid placement (`column` / `row` / `align` /
   * `justify`) so the layout can position each direct child.
   *
   * Returns the entry to insert. When no annotation is needed
   * (destination isn't a grid) returns the entry unchanged. When the
   * entry is already a grid cell occupant (already has
   * `containerArgs.grid`) returns it unchanged — its existing placement
   * is preserved.
   *
   * New cell occupants default to `auto / auto` so CSS Grid auto-places
   * them into the next free cell; authors reposition later via the
   * grid overlay.
   *
   * @param {{entry: Object, layout: Array<Object>, targetKey: string|null, position: string}} args
   * @returns {Object}
   */
  _annotateForDestination({ entry, layout, targetKey, position }) {
    if (!entry) {
      return entry;
    }
    const parent = this._destinationParentEntry({
      layout,
      targetKey,
      position,
    });
    const enteringGrid = this._isGridContainer(parent);

    if (enteringGrid) {
      if (entry.containerArgs?.grid) {
        return entry;
      }
      return {
        ...entry,
        containerArgs: {
          ...(entry.containerArgs ?? {}),
          grid: {
            column: "auto",
            row: "auto",
            align: "stretch",
            justify: "stretch",
          },
        },
      };
    }

    // Leaving any grid: strip the `grid` namespace; clear `containerArgs`
    // entirely if no other namespaces remain so serialised output stays
    // clean and core's `validateOrphanContainerArgs` doesn't warn.
    if (!entry.containerArgs?.grid) {
      return entry;
    }
    const remaining = { ...entry.containerArgs };
    delete remaining.grid;
    if (Object.keys(remaining).length === 0) {
      const stripped = { ...entry };
      delete stripped.containerArgs;
      return stripped;
    }
    return { ...entry, containerArgs: remaining };
  }

  /**
   * Single entry point that picks between annotating and stripping
   * `containerArgs.grid` based on the entry's current shape and the
   * destination's parent. Returns the entry-to-insert; entry identity
   * is preserved when only the bag changes, so callers can rely on
   * `moveEntry` rather than a `remove + insert` round-trip.
   *
   * @param {{entry: Object, layout: Array<Object>, targetKey: string|null, position: string}} args
   * @returns {Object}
   */
  _transformForDestination({ entry, layout, targetKey, position }) {
    return this._annotateForDestination({ entry, layout, targetKey, position });
  }

  /**
   * Resolves the entry that will contain the inserted / moved entry.
   *
   *  - "inside" position → `targetKey` is the parent.
   *  - "before" / "after" → the entry one level above `targetKey`.
   *  - `targetKey === null` → outlet root (no block-level parent).
   *
   * Returns `null` for the outlet-root case.
   */
  _destinationParentEntry({ layout, targetKey, position }) {
    if (!targetKey) {
      return null;
    }
    if (position === "inside") {
      return findEntry(layout, targetKey);
    }
    const path = findAncestryPath(layout, targetKey);
    if (!path || path.length < 2) {
      return null;
    }
    return path[path.length - 2];
  }

  /**
   * Whether the entry is a `ve:layout` in per-cell `grid` mode. Accepts
   * the legacy `"free-grid"` mode value as an alias so existing saved
   * layouts (pre-rename) keep working.
   *
   * @param {Object|null} entry
   * @returns {boolean}
   */
  _isGridContainer(entry) {
    if (this._blockNameOf(entry) !== "ve:layout") {
      return false;
    }
    const mode = entry?.args?.mode;
    return mode === "grid" || mode === "free-grid";
  }

  /**
   * Whether the entry is a grid-cell occupant — a direct child of a
   * `ve:layout` in grid mode, carrying its own `containerArgs.grid`
   * placement. Used by the editor to decide whether a given entry can
   * be placement-mutated (set its column/row, swap with a sibling, etc.).
   *
   * @param {Object|null} entry
   * @returns {boolean}
   */
  _isGridCellEntry(entry) {
    return entry?.containerArgs?.grid != null;
  }

  /**
   * Re-publishes a draft layout layer with structural changes applied and
   * marks the outlet as edited so save/reset/isDirty all pick it up.
   * Centralised so the same bookkeeping fires for every structural
   * mutation.
   */
  _publishStructuralChange(outletName, newLayout) {
    _setLayoutLayer(
      outletName,
      LAYOUT_LAYERS.SESSION_DRAFT,
      newLayout,
      getOwner(this),
      // Permissive matches the initial draft publish — see comment on
      // `_materializeAllDrafts`. Without this, dragging the only child
      // out of a container produces an "EMPTY_CONTAINER" validation
      // failure which would crash the page.
      { permissive: true }
    );
    this._editedOutlets.add(outletName);
    this._structurallyEditedOutlets.add(outletName);
    this.structuralVersion++;
  }

  /**
   * Synchronous variant of `_findEntryAndOutlet` — uses `record.layout`
   * (already-resolved) instead of awaiting `record.validatedLayout`. Drag
   * handlers fire after validation has long since completed, so the sync
   * lookup is safe and avoids forcing every call site to be async.
   *
   * @param {string} key
   * @returns {{entry: Object, outletName: string}|null}
   */
  _findEntryAndOutletSync(key) {
    const layoutMap = _getOutletLayouts();
    for (const [outletName, record] of layoutMap) {
      if (!record.layout) {
        continue;
      }
      const found = findEntry(record.layout, key);
      if (found) {
        return { entry: found, outletName };
      }
    }
    return null;
  }

  /** @param {string} key */
  _findEntryByKey(key) {
    return this._findEntryAndOutletSync(key)?.entry ?? null;
  }

  _metadataFor(entry) {
    if (!entry?.block) {
      return null;
    }
    if (typeof entry.block === "string") {
      // String-ref blocks (`api.renderBlocks(name, ...)` paths) expose their
      // metadata via the registered class — looked up through the blocks
      // service. Skipping for now keeps the perms check simple.
      return null;
    }
    return getBlockMetadata(entry.block) ?? null;
  }
}
