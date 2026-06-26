// @ts-check
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { trackedMap, trackedSet } from "@ember/reactive/collections";
import { schedule } from "@ember/runloop";
import Service, { service } from "@ember/service";
import {
  DEFAULT_GRID_COLUMNS,
  DEFAULT_GRID_ROWS,
  gridDimensions,
  LAYOUT_MERGED_CELL_BLOCK,
  parsePlacement,
  registerBlockArgRenderer,
  resetBlockArgRenderer,
} from "discourse/blocks";
import {
  _clearLayoutLayer,
  _getResolvedLayouts,
  _setLayoutLayer,
  LAYOUT_LAYERS,
  LAYOUT_SOURCE,
} from "discourse/blocks/block-outlet";
import { VALID_BLOCK_ID_PATTERN } from "discourse/lib/blocks/-internals/patterns";
import discourseDebounce from "discourse/lib/debounce";
import loadInlineRichEditor from "discourse/lib/load-inline-rich-editor";
import PreloadStore from "discourse/lib/preload-store";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import { i18n } from "discourse-i18n";
import { imageArgEntries } from "discourse/plugins/discourse-wireframe/discourse/lib/empty-image-upload";
// `grid-math` holds the editor-only grid geometry. Absolute addon path
// because this admin service crosses into the plugin's universal bundle.
import {
  cellsForFree,
  contentCells,
  isMergedCell,
  placementsOverlap,
  reflowChildrenIntoCells,
  syncContentToArrayOrder,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-math";
import ConflictModal from "../components/editor/conflict-modal";
import StaleDraftModal from "../components/editor/stale-draft-modal";
import ScaffoldedRichTextRenderer from "../components/scaffolded-rich-text-renderer";
import BlockReveal from "../lib/block-reveal";
import DragSessionState from "../lib/drag-session-state";
import DropAuthority from "../lib/drop-authority";
import GridManipulator from "../lib/grid-manipulator";
import {
  matchGridTemplate,
  resolveTemplateLayout,
} from "../lib/grid-templates";
import IconEditState from "../lib/icon-edit-state";
import InlineEditState from "../lib/inline-edit-state";
import LinkEditState from "../lib/link-edit-state";
import {
  cloneEntryForPaste,
  cloneLayoutForDraft,
  detachComposite,
  entryKey,
  findAncestryPath,
  findEntry,
  findEntrySiblings,
  insertEntryAt,
  moveEntry,
  normalizeImplicitChildren,
  removeEntry,
  replaceEntryConditions,
  replaceEntryContainerArgs,
  replaceEntryId,
  replaceEntryInPlace,
  serializeLayoutForSave,
  setPartOverride,
  wrapAsOutletRoot,
} from "../lib/mutate-layout";
import { diffLayouts } from "../lib/outlet-change-summary";
import { isReversedFlexLayout } from "../lib/reversed-flex";
import { OUTLET_STATE } from "../services/wireframe-layout-query";

const FLUSH_DELAY_MS = 200;

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
  @service site;
  @service siteSettings;
  @service wireframeDrafts;
  @service wireframeDragOverlay;
  @service wireframeEditEngine;
  @service wireframeLayoutQuery;
  @service wireframePersistence;
  @service wireframeRevision;
  @service wireframeSelection;

  @tracked isActive = false;

  /**
   * The id of the theme this editor session is bound to. Set on `enter()`
   * — explicit `themeId` argument takes precedence; otherwise we fall back
   * to whichever user-selectable theme is marked default on the site. The
   * persistence service uses this when posting saves; if it remains null,
   * the toolbar's Save button stays disabled.
   *
   * The URL-based theme chooser sets this via `enter({ themeId })` so
   * admins picking a theme from the admin show page land here with
   * the right target.
   *
   * @type {number|null}
   */
  @tracked activeThemeId = null;

  /**
   * Whether the inspector's conditions surface is detached from the
   * right rail and rendered in a floating panel. Toggled by the
   * inspector's `↗` button and the panel's `↙` redock button.
   * Persisted to localStorage so the preference survives reloads.
   *
   * @type {boolean}
   */
  @tracked conditionsDetached = false;

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
   * Floating-panel rect (`{x, y, width, height}`) for the detached
   * conditions surface. Updated by the panel's drag and resize
   * handlers and persisted to localStorage. Null while no rect has
   * been chosen yet — the panel renders centred on first open.
   *
   * @type {{x: number, y: number, width: number, height: number}|null}
   */
  @tracked conditionsPanelRect = null;

  /**
   * Contextual toolbar slot — when non-null, the block toolbar
   * transitions into a field-editing mode driven by this state instead
   * of showing default block actions. Generic shape:
   * `{ kind, value, apply, cancel, remove? }`. PM's link-mark editing
   * AND block-arg URL editing both populate this with `kind: "url"`;
   * future kinds (e.g. `"color"`, `"image"`) plug into the same slot
   * without re-architecting. Exactly one slot is active at a time —
   * a new source setting it implicitly closes the previous session.
   *
   * @type {Object|null}
   */
  @tracked fieldEditor = null;

  /**
   * Tracks the most recently interacted-with image arg name for the
   * selected block. Used to route a paste to the right arg on
   * multi-image blocks (e.g. media-card avatar vs cover image).
   * Updated by the chrome's image-arg overlay on focus / hover / click;
   * cleared on selection change.
   *
   * @type {string|null}
   */
  @tracked lastTouchedImageArg = null;

  /**
   * Inline-text-edit session state. Holds the active `(blockKey, argName)`,
   * the cached entry location, the pre-edit snapshot for undo, the
   * registered controller, structural ops (split / merge), and sibling
   * lookups consumed by the keymap.
   *
   * Lives as a separate object so the service file stays focused on
   * layout / palette / clipboard / undo concerns. Service-owned utilities
   * (layout lookup, draft management, structural recording, undo stack)
   * are reached back through `this` via the constructor back-reference.
   *
   * @type {InlineEditState}
   */
  inlineEdit = new InlineEditState(this);

  /**
   * Inline icon-edit session state + operations. Mirrors `inlineEdit`'s
   * separate-object split: opens a FloatKit popover anchored to the
   * clicked icon, hosting `DIconGridPickerContent` for the user to pick
   * from. See `../lib/icon-edit-state.js`.
   *
   * @type {IconEditState}
   */
  iconEdit = new IconEditState(this);

  /**
   * Inline URL-edit session state + operations. Same separate-object
   * split: when started, populates `fieldEditor` with the URL slot so
   * the block toolbar transitions into URL-edit mode. See
   * `../lib/link-edit-state.js`.
   *
   * @type {LinkEditState}
   */
  linkEdit = new LinkEditState(this);

  /**
   * Owns every grid `wf:layout` mutation. Drops route through it so they
   * can't bypass the `decideGridDrop` rule chokepoint; non-drop grid ops
   * (cell / column resize) live here too. Same separate-object split as the
   * inline editors, reaching service primitives back through `this`. See
   * `../lib/grid-manipulator.js`.
   *
   * @type {GridManipulator}
   */
  gridManipulator = new GridManipulator(this);

  /**
   * Drag-session state (what block / palette entry is being dragged). A pure
   * dependency-free leaf the kernel drives one-way: `startDrag` /
   * `startPaletteDrag` / `endDrag` mutate it and add the side effects (body
   * class, overlay reset). Read externally only through the `dragSourceKey` /
   * `isDragging` facade getters. See `../lib/drag-session-state.js`.
   *
   * @type {DragSessionState}
   */
  dragSession = new DragSessionState();

  /**
   * Drop authorization (the per-dragover `canDropAt` / `canInsertBlockAt`
   * allow/deny checks). A pure-read leaf the kernel configures downward with the
   * drag-session leaf + opaque query lookups; it never reaches back here. Exposed
   * directly (read-only) so drop targets call `wireframe.dropAuthority.canDropAt`.
   * Declared after `dragSession` so that reference is set when this initializes.
   * See `../lib/drop-authority.js`.
   *
   * @type {DropAuthority}
   */
  dropAuthority = new DropAuthority({
    session: this.dragSession,
    findEntryByKey: (key) => this.layoutQuery.findEntryByKey(key),
    metadataFor: (entry) => this.layoutQuery.metadataFor(entry),
    metadataForName: (name) => this.layoutQuery.metadataForName(name),
  });

  /**
   * Reveal-into-view and the one-shot "just selected" flash. A dependency-free
   * leaf the kernel configures downward with the draft-aware layout readers; it
   * never reaches back here. Side-effecting (DOM + timers), so it stays private
   * and the kernel drives it (the externally-called `notifyChromeInserted` /
   * `flashBlock` are thin delegators below). See `../lib/block-reveal.js`.
   *
   * @type {BlockReveal}
   */
  #blockReveal = new BlockReveal({
    findEntryAndOutletSync: (key) =>
      this.layoutQuery.findEntryAndOutletSync(key),
    readResolvedLayout: (outletName) =>
      this.layoutQuery.readResolvedLayout(outletName),
  });

  /**
   * Files dropped onto an empty slot, staged by `"blockKey\0argName"` until
   * the freshly-created block's `ImageArgOverlay` mounts and uploads them
   * through its own pipeline. One-shot per entry; cleared on enter / exit.
   *
   * @type {Map<string, File>}
   */
  #pendingDropFiles = new Map();

  /**
   * Whether the drop-dispatch handler has been registered on
   * `wireframeDragOverlay`. Guards `enter()` so re-entry doesn't re-register.
   */
  #dropDispatchRegistered = false;

  /**
   * Whether this kernel's cross-concern selection hooks have been registered
   * on `wireframeSelection`. Guards `enter()` so re-entry doesn't re-register
   * (which would flush args / commit edits / reveal multiple times per
   * selection change).
   */
  #selectionHooksRegistered = false;

  /**
   * Pending arg changes for the currently-selected block, accumulated across
   * a burst of keystrokes and flushed by `#flushPendingArgs` after a short
   * idle delay. Keys are arg names; values are the latest value typed.
   *
   * @type {Map<string, *>}
   */
  #pendingArgs = new Map();

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
   * `wf:layout` block keys that the author has explicitly asked to
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
  #forceExpandedKeys = trackedSet();

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

  constructor() {
    super(...arguments);
    this.#loadConditionsPanelState();
    this.#installImagePasteListener();
    this.#installFileDragGuard();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.#uninstallImagePasteListener();
    this.#uninstallFileDragGuard();
    this.#blockReveal.reset();
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
   * The theme an outlet publishes to when nothing yet owns it (a pure in-code
   * default with no live field). Exposed publicly so the persistence and drafts
   * services can resolve a fallback publish target without reaching into the
   * private resolver.
   *
   * @returns {number|null}
   */
  get defaultThemeId() {
    return this.#defaultThemeId();
  }

  /**
   * Whether the editor is bound to a core "system" theme (Foundation, Horizon),
   * which have negative ids. Such themes can't be published to directly — the
   * editor offers an installable companion component instead — so the toolbar
   * uses this to disable the direct Publish action.
   *
   * @returns {boolean}
   */
  get activeThemeIsSystem() {
    return this.activeThemeId != null && this.activeThemeId < 0;
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

  /**
   * The block being dragged, or `null`. Read externally by the outline to
   * highlight the drag source; delegates to the drag-session leaf (read-only —
   * drag state is mutated only through `startDrag` / `endDrag`).
   *
   * @returns {?string}
   */
  get dragSourceKey() {
    return this.dragSession.sourceKey;
  }

  /** @returns {boolean} */
  get isDragging() {
    return this.dragSession.isDragging;
  }

  /**
   * Validation warnings across every outlet the editor is currently
   * drafting. Walks each outlet's resolved layout and harvests the
   * per-entry `__failureReason` stamps the permissive validator leaves
   * behind (paired 1:1 with the layer-level warnings — see
   * `validation/layout.js`'s `markEntrySoftFailure` + `context.warnings`).
   *
   * Reading the stamps rather than the layer record's frozen
   * `validationWarnings` array is what lets the inspector banner clear
   * the moment the author fixes a failing arg: in-place arg writes go
   * through `writeArgs`, which deletes the entry's stamps but doesn't
   * touch the layer array. The two surfaces (per-block ghost chrome,
   * outlet-wide banner) now agree on the live state.
   *
   * Reactivity: reads `structuralVersion` so structural republishes
   * re-evaluate; entry stamp reads (on the trackedObject-wrapped entry)
   * open their own deps so arg-edit stamp clears propagate too.
   * Validation itself is async (`validatedLayout` is a lazy Promise
   * resolved after `BlockOutlet` first reads it); on the very first
   * render after a publish, stamps may not yet be populated and this
   * getter returns an empty list until the next tick.
   *
   * @returns {Array<{outletName: string, message: string}>}
   */
  get validationWarnings() {
    // `structuralVersion` covers republishes (validation re-runs against
    // the freshly-published layer). In-place stamp changes propagate via
    // the per-entry `trackedObject` wrap — each `entry.__failureReason`
    // read below opens a per-key dep that fires when `revalidateEntryStamps`
    // rewrites or deletes `entry.__failureReason` on an arg edit.
    void this.structuralVersion;
    const layoutMap = _getResolvedLayouts();
    const warnings = [];
    for (const [outletName, record] of layoutMap) {
      if (!record?.layout) {
        continue;
      }
      this.#collectStampedWarnings(record.layout, outletName, warnings);
    }
    return warnings;
  }

  /** @returns {boolean} */
  get hasValidationWarnings() {
    return this.validationWarnings.length > 0;
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

  /**
   * Toggles the conditions detach state. Reads / writes localStorage
   * so the preference survives reloads.
   */
  @action
  toggleConditionsDetached() {
    this.conditionsDetached = !this.conditionsDetached;
    this.#persistConditionsPanelState();
  }

  @action
  closeConditionsPanel() {
    this.conditionsDetached = false;
    this.#persistConditionsPanelState();
  }

  @action
  updateConditionsPanelRect(rect) {
    this.conditionsPanelRect = rect;
    this.#persistConditionsPanelState();
  }

  @action
  enter({ themeId } = {}) {
    if (!this.canEdit) {
      return;
    }
    this.isActive = true;
    this.#pendingDropFiles.clear();
    // Hand the overlay our drop dispatcher so it never reaches up into this
    // service. Synchronous + returns a boolean (the `completeExternalImageDrop`
    // contract). Registered once; the guard keeps re-entry from re-wrapping it.
    if (!this.#dropDispatchRegistered) {
      this.wireframeDragOverlay.registerDispatcher((payload) =>
        this.runDropDispatch(payload)
      );
      this.#dropDispatchRegistered = true;
    }
    // Wire this kernel's cross-concern effects into the selection seam. The
    // selection service owns "what is selected"; these hooks own the editor's
    // reactions to a selection change. Registered once; the guard keeps
    // re-entry from firing them more than once per change.
    if (!this.#selectionHooksRegistered) {
      this.wireframeSelection.registerBeforeChange(({ nextKey }) => {
        // Flush anything still pending from the previous selection so we don't
        // apply those keystrokes to the new block by accident.
        if (this.#pendingArgs.size > 0) {
          this.#flushPendingArgs();
        }
        // Switching selection to a different block commits any in-flight
        // inline-edit session. Re-selecting the same block leaves it alone —
        // that case is the second-click-to-edit gesture.
        if (this.inlineEdit.blockKey && this.inlineEdit.blockKey !== nextKey) {
          this.inlineEdit.stop({ commit: true });
        }
      });
      this.wireframeSelection.registerAfterChange(({ key }) =>
        // Bring the freshly selected block into view (outline selection,
        // insert auto-select, undo/redo restore). No-ops when it's already
        // visible, so clicking a block on the canvas doesn't jolt the page.
        this.#blockReveal.revealSelection(key)
      );
      this.#selectionHooksRegistered = true;
    }
    // New session generation: invalidates any draft hydration still in flight
    // from a previous enter/exit so it can't write into this session.
    const generation = ++this.#enterGeneration;
    this.activeThemeId = themeId ?? this.#defaultThemeId();
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
   * Ensures a session-draft layer exists for `outletName`. Used by
   * mutation actions that target outlets the user is populating from
   * scratch — those outlets have no published layout (so
   * `#materializeAllDrafts` skips them on `enter()`), but the
   * editor's empty-outlet drop zone lets authors add the first
   * block. We mint an empty draft `[]` here so the subsequent
   * `publishStructuralChange` has somewhere to land.
   *
   * Idempotent: bails when a draft already exists.
   *
   * @param {string} outletName
   * @returns {Array<Object>} the layout array (existing or freshly minted).
   */
  ensureDraft(outletName) {
    const existing = this.layoutQuery.readResolvedLayout(outletName);
    if (existing) {
      return existing;
    }
    // A LOCKED outlet is read-only — never mint a draft for it. This is a
    // defensive backstop; the chrome already gates writes on `isOutletEditable`.
    if (this.layoutQuery.outletState(outletName) === OUTLET_STATE.LOCKED) {
      return existing ?? [];
    }
    // Seed the outlet with an empty root `layout` block so it's an implicit
    // layout from the first drop, matching `#materializeAllDrafts`.
    const emptyDraft = wrapAsOutletRoot([]);
    _setLayoutLayer(
      outletName,
      LAYOUT_LAYERS.SESSION_DRAFT,
      emptyDraft,
      getOwner(this),
      { permissive: true }
    );
    this.wireframeEditEngine.markOutletDrafted(outletName);
    this.layoutQuery.recordOutletRoot(outletName);
    this.wireframeEditEngine.captureBaseline(
      outletName,
      cloneLayoutForDraft(this.layoutQuery.readResolvedLayout(outletName) ?? [])
    );
    return this.layoutQuery.readResolvedLayout(outletName) ?? emptyDraft;
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

    this.isActive = false;
    this.reviewDrawerOpen = false;
    this.publishTargetResolving = false;
    this.activeThemeId = null;
    // Tear the selection down WITHOUT firing the select hooks (flush args,
    // commit in-session edits, reveal-into-view) — they're meaningless once
    // the session is ending, and `selectBlock(null)` would fire them.
    this.wireframeSelection.reset();
    this.dragSession.clear();
    this.wireframeDragOverlay.clear();
    this.#blockReveal.reset();
    this.#pendingDropFiles.clear();
    // Revert to the minimal rich-text renderer so admin pages without
    // an open editor render the same DOM as live.
    resetBlockArgRenderer("rich-text");
    this.#pendingArgs.clear();
    this.#persistedDraftLayouts.clear();
    this.#forceExpandedKeys.clear();
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
   * Removes the block matching `blockKey` from whichever outlet currently
   * holds it. Used by the inspector's recovery actions (e.g. "Remove
   * empty container") and by future delete affordances. Routes through
   * `publishStructuralChange` so the bookkeeping (edited-outlets,
   * structural-version, isDirty signal) matches a drag-driven move.
   *
   * @param {string} blockKey
   * @returns {boolean} true on success
   */

  /**
   * Shared body for the floating block toolbar's move up / down buttons.
   * Looks up the selected entry's siblings and computes a `moveBlock` call
   * against the previous / next sibling in the direction the author SEES.
   *
   * A reversed flex parent (stack / row with `reverse`) renders its children
   * in reverse, so a visual "up" is a move toward a LATER persisted index (and
   * vice versa). The visual direction is mapped to the persisted one before
   * picking the target sibling, so the buttons always move the block the way
   * the author expects on screen.
   *
   * Returns `false` (no-op) when the block is already first / last (visually)
   * in its parent, when no block is selected, or when the move is rejected.
   *
   * @param {string} blockKey
   * @param {"up"|"down"} visualDirection
   * @returns {boolean}
   */
  #moveBlockSibling(blockKey, visualDirection) {
    const located = this.layoutQuery.findEntryAndOutletSync(blockKey);
    if (!located) {
      return false;
    }
    const layout = this.layoutQuery.readResolvedLayout(located.outletName);
    if (!layout) {
      return false;
    }
    const sibs = findEntrySiblings(layout, blockKey);
    if (!sibs) {
      return false;
    }
    const reversed = isReversedFlexLayout(
      this.layoutQuery.findEntryParent(blockKey)?.args
    );
    const goEarlier = reversed
      ? visualDirection === "down"
      : visualDirection === "up";

    if (goEarlier) {
      if (sibs.index === 0) {
        return false;
      }
      return this.moveBlock({
        sourceKey: blockKey,
        targetKey: entryKey(sibs.siblings[sibs.index - 1]),
        position: "before",
        targetOutletName: located.outletName,
      });
    }
    if (sibs.index >= sibs.siblings.length - 1) {
      return false;
    }
    return this.moveBlock({
      sourceKey: blockKey,
      targetKey: entryKey(sibs.siblings[sibs.index + 1]),
      position: "after",
      targetOutletName: located.outletName,
    });
  }

  /**
   * @param {string} blockKey
   * @returns {boolean}
   */
  @action
  moveBlockUp(blockKey) {
    return this.#moveBlockSibling(blockKey, "up");
  }

  /**
   * @param {string} blockKey
   * @returns {boolean}
   */
  @action
  moveBlockDown(blockKey) {
    return this.#moveBlockSibling(blockKey, "down");
  }

  /**
   * Inserts `count` fresh clones of the given block immediately after it in
   * the layout. Used by the block toolbar's `Duplicate` button (`count = 1`)
   * and its "duplicate ×N" menu. All clones land in a single structural
   * transaction, so the whole batch is one undo step. The clones are identical,
   * so their relative order among themselves is irrelevant.
   *
   * @param {string} blockKey
   * @param {number} [count=1] - How many clones to insert (clamped to >= 1).
   * @returns {boolean}
   */
  @action
  duplicateBlock(blockKey, count = 1) {
    const located = this.layoutQuery.findEntryAndOutletSync(blockKey);
    if (!located) {
      return false;
    }
    const copies = Math.max(1, Math.floor(count));
    return this.recordStructural([located.outletName], () => {
      let layout = this.layoutQuery.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      let changed = false;
      for (let i = 0; i < copies; i++) {
        const insertion = insertEntryAt(
          layout,
          blockKey,
          cloneEntryForPaste(located.entry),
          "after"
        );
        if (insertion.changed) {
          layout = insertion.layout;
          changed = true;
        }
      }
      if (!changed) {
        return false;
      }
      this.publishStructuralChange(located.outletName, layout);
      return true;
    });
  }

  @action
  removeBlock(blockKey) {
    // The implicit root layout IS the outlet; deleting it would remove the
    // whole page region. Block-level delete is a no-op on the root — the
    // toolbar and inspector already hide the affordance, and this guard
    // also closes the keyboard (Delete / Backspace) and cut (Cmd+X) paths
    // that reach `removeBlock` directly.
    if (this.layoutQuery.isOutletRoot(blockKey)) {
      return false;
    }
    const located = this.layoutQuery.findEntryAndOutletSync(blockKey);
    if (!located) {
      return false;
    }
    return this.recordStructural([located.outletName], () => {
      const layout = this.layoutQuery.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const result = this.#removeEntryFromLayout(
        layout,
        blockKey,
        located.entry
      );
      if (!result.changed) {
        return false;
      }
      if (this.selectedBlockKey === blockKey) {
        this.selectBlock(null);
      }
      this.publishStructuralChange(located.outletName, result.layout);
      return true;
    });
  }

  /**
   * Removes several blocks in a single structural transaction, so the whole
   * batch is one undo step. Used by the multi-selection's bulk delete (the
   * inspector panel + the Delete shortcut). Outlet roots are skipped; a
   * container and one of its descendants both being selected is safe — once the
   * container is gone the descendant key simply no longer matches.
   *
   * @param {Array<string>} keys
   * @returns {boolean} Whether anything was removed.
   */
  @action
  removeBlocks(keys) {
    const located = (keys ?? [])
      .filter((key) => !this.layoutQuery.isOutletRoot(key))
      .map((key) => ({ key, ...this.layoutQuery.findEntryAndOutletSync(key) }))
      .filter((entry) => entry.entry);
    if (located.length === 0) {
      return false;
    }
    const outletNames = [...new Set(located.map((l) => l.outletName))];
    return this.recordStructural(outletNames, () => {
      let anyChanged = false;
      for (const outletName of outletNames) {
        let layout = this.layoutQuery.readResolvedLayout(outletName);
        if (!layout) {
          continue;
        }
        let outletChanged = false;
        for (const { key, entry } of located.filter(
          (l) => l.outletName === outletName
        )) {
          const result = this.#removeEntryFromLayout(layout, key, entry);
          if (result.changed) {
            layout = result.layout;
            outletChanged = true;
          }
        }
        if (outletChanged) {
          this.publishStructuralChange(outletName, layout);
          anyChanged = true;
        }
      }
      if (anyChanged) {
        this.selectBlock(null);
      }
      return anyChanged;
    });
  }

  /**
   * Removes a single entry from `layout` by key, preserving a multi-cell grid
   * placement as an empty merged-cell entry (keeps the author's layout shape —
   * a hero spanning 3 columns, a sidebar rail — intact even when its content is
   * removed); single-cell entries are removed outright. Returns the
   * `{ layout, changed }` result without publishing.
   *
   * @param {Array<Object>} layout
   * @param {string} key
   * @param {Object} entry - The located entry (for its `containerArgs`).
   * @returns {{layout: Array<Object>, changed: boolean}}
   */
  #removeEntryFromLayout(layout, key, entry) {
    return this.#shouldRestoreAsCell(layout, entry, key)
      ? replaceEntryInPlace(layout, key, {
          block: LAYOUT_MERGED_CELL_BLOCK,
          containerArgs: entry.containerArgs,
        })
      : removeEntry(layout, key);
  }

  /**
   * Replaces the `conditions` tree on the currently-selected block.
   * Used by the visual condition builder in the inspector to push edits
   * back to the layout. Pass `null` to clear all conditions.
   *
   * Conditions affect *whether* a block renders, so this is a structural
   * change — routes through `publishStructuralChange` to keep
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
    const located = this.layoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return false;
    }
    return this.recordStructural([located.outletName], () => {
      const layout = this.layoutQuery.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const result = replaceEntryConditions(layout, key, newConditions);
      if (!result.changed) {
        return false;
      }
      this.publishStructuralChange(located.outletName, result.layout);
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
    const located = this.layoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return { ok: false, error: "not-found" };
    }
    const committed = this.recordStructural([located.outletName], () => {
      const layout = this.layoutQuery.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const result = replaceEntryId(layout, key, trimmed || null);
      if (!result.changed) {
        return false;
      }
      this.publishStructuralChange(located.outletName, result.layout);
      return true;
    });
    return { ok: !!committed, error: null };
  }

  /**
   * Replaces the selected entry with a wholly new entry object. Used
   * by the inspector's Raw JSON tab — the author edits the entry's
   * serialised form and commits the parsed result.
   *
   * Routes through `publishStructuralChange` because changes can
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
    const located = this.layoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return false;
    }
    // The outlet root must stay a single `layout` block. If a raw edit
    // changes its block away from `layout`, re-wrap so the invariant holds —
    // the edited entry then becomes the root layout's child.
    const nextEntry = this.layoutQuery.isOutletRoot(key)
      ? wrapAsOutletRoot([parsed])[0]
      : parsed;
    return this.recordStructural([located.outletName], () => {
      const layout = this.layoutQuery.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const result = replaceEntryInPlace(layout, key, nextEntry);
      if (!result.changed) {
        return false;
      }
      this.publishStructuralChange(located.outletName, result.layout);
      return true;
    });
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
    const located = this.layoutQuery.findEntryAndOutletSync(key);
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
    const located = this.layoutQuery.findEntryAndOutletSync(key);
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
    const located = this.layoutQuery.findEntryAndOutletSync(targetKey);
    if (!located) {
      return false;
    }
    return this.recordStructural([located.outletName], () => {
      const layout = this.layoutQuery.readResolvedLayout(located.outletName);
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
      this.publishStructuralChange(located.outletName, insertion.layout);
      return true;
    });
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
   * selected. See `../lib/block-reveal.js`.
   *
   * @param {string} blockKey - The mounting block's composite key.
   * @param {HTMLElement} element - The block's chrome element.
   */
  notifyChromeInserted(blockKey, element) {
    this.#blockReveal.notifyChromeInserted(blockKey, element);
  }

  /**
   * Briefly flashes the rendered element for the given block key to draw the
   * eye to it — used when selection originates somewhere other than a direct
   * click on the block (outline selection, insert auto-select). Delegates to
   * the reveal/flash leaf. See `../lib/block-reveal.js`.
   *
   * @param {string|null} blockKey - The composite key of the block to flash.
   */
  flashBlock(blockKey) {
    this.#blockReveal.flash(blockKey);
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
    this.#pendingArgs.set(argName, value);
    discourseDebounce(this, this.#flushPendingArgs, FLUSH_DELAY_MS);
  }

  /**
   * Uploads a single File to the Discourse uploads endpoint and writes
   * the result into a block's image arg. Used by the inline editing
   * overlays (click-to-pick, drag-and-drop, paste) so the canvas can
   * mutate image args without the inspector being open.
   *
   * Writes to the specific `blockKey` rather than the currently-selected
   * block, so a slow upload doesn't race with the user clicking around
   * the canvas.
   *
   * One-shot UppyUpload instance per call — uniquely id'd by argName +
   * timestamp to avoid the duplicate-id error when multiple uploads
   * race. The instance tears itself down on success or failure.
   *
   * @param {File|Blob} file
   * @param {Object} options
   * @param {string} options.blockKey - The block whose arg to write.
   * @param {string} options.argName - The image arg name on that block.
   * @returns {Promise<{url: string, width?: number, height?: number}|null>}
   *   The upload result on success, `null` on failure (the consumer
   *   surfaces its own error UI).
   */
  uploadImageForArg(file, { blockKey, argName }) {
    if (!file || !blockKey || !argName) {
      return Promise.resolve(null);
    }
    const owner = getOwner(this);
    const uploadId = `wireframe-image-${argName}-${Date.now()}`;
    return new Promise((resolve) => {
      let settled = false;
      const finish = (result) => {
        if (settled) {
          return;
        }
        settled = true;
        try {
          upload.teardown();
        } catch {
          // Tearing down before Uppy fully boots can throw — safe to ignore.
        }
        resolve(result);
      };

      const upload = new UppyUpload(owner, {
        id: uploadId,
        type: "composer",
        uploadDone: (result) => {
          // Persist `upload_id` so the server-side cleanup can create an
          // UploadReference for this image when the layout saves; without it
          // the upload would be considered orphan and garbage-collected by
          // Jobs::CleanUpUploads after the 48h grace period.
          this.setImageArg(blockKey, argName, {
            source: "upload",
            upload_id: result.id,
            url: result.url,
            width: result.width,
            height: result.height,
          });
          finish({
            url: result.url,
            width: result.width,
            height: result.height,
          });
        },
      });

      upload.setup();
      upload.uppyWrapper?.uppyInstance?.on("upload-error", () => finish(null));
      upload.addFiles(file);
    });
  }

  /**
   * Completes an OS image-file drop onto an empty, block-accepting slot.
   * The dragover handlers have already published the drop preview (built
   * from the synthetic image-block source), so this runs the pending drop
   * the same way a palette drop does, then hands the dropped file to the
   * freshly-created block.
   *
   * `wireframeDragOverlay.dispatch()` inserts and auto-selects an empty image
   * block at the previewed slot synchronously. Rather than uploading here, the
   * file is STAGED against the new block's key: the block's own `ImageArgOverlay`
   * picks it up as it mounts and uploads it through the overlay pipeline, so
   * the upload shows the per-block progress bar, surfaces errors, and writes
   * only to that block (the overlay always uses its own live key — an upload
   * can never land on a different block). A rejected / invalid drop
   * dispatches nothing, so this is a no-op.
   *
   * @param {File} file - The image file to upload into the new block.
   * @returns {boolean} `true` when a block was created and the file staged.
   */
  completeExternalImageDrop(file) {
    if (!file) {
      return false;
    }
    // Run the pending drop. A false return means the slot rejected the
    // image block, so there's nothing to fill.
    if (!this.wireframeDragOverlay.dispatch()) {
      return false;
    }
    const blockKey = this.selectedBlockKey;
    if (!blockKey) {
      return false;
    }
    // Derive the target arg from the inserted block's own schema rather
    // than assuming a name, mirroring how the paste handler picks its arg.
    const argName = imageArgEntries(this.selectedBlockData?.metadata?.args)[0]
      ?.name;
    if (!argName) {
      return false;
    }
    this.stagePendingDropFile(blockKey, argName, file);
    return true;
  }

  /**
   * Stages a dropped file against a block's image arg so the block's
   * `ImageArgOverlay` can upload it through its own pipeline once it mounts.
   * One-shot: `consumePendingDropFile` reads and removes it.
   *
   * @param {string} blockKey
   * @param {string} argName
   * @param {File} file
   */
  stagePendingDropFile(blockKey, argName, file) {
    this.#pendingDropFiles.set(JSON.stringify([blockKey, argName]), file);
  }

  /**
   * Returns and removes the file staged for a block's image arg, or `null`
   * when none was staged. Called by the arg's overlay as it sets up.
   *
   * @param {string} blockKey
   * @param {string} argName
   * @returns {File|null}
   */
  consumePendingDropFile(blockKey, argName) {
    const key = JSON.stringify([blockKey, argName]);
    const file = this.#pendingDropFiles.get(key) ?? null;
    if (file) {
      this.#pendingDropFiles.delete(key);
    }
    return file;
  }

  /**
   * Writes a single arg value into the entry identified by `blockKey`,
   * routing through the same write-path as inspector edits so undo /
   * redo / persistence stay consistent. Resolves the entry
   * synchronously via `findEntryAndOutletSync` so the canvas re-renders
   * before the next paint instead of waiting for an async resolution.
   *
   * Low-level write-path shared by the image affordances: the inline
   * image overlays and edit menu call this directly, and helpers like
   * `uploadImageForArg` build the full image-value shape before routing
   * here. Prefer those helpers when constructing a value from scratch.
   *
   * @param {string} blockKey
   * @param {string} argName
   * @param {*} value
   */
  setImageArg(blockKey, argName, value) {
    this.setArg(blockKey, argName, value);
  }

  /**
   * Updates one field inside a `containerArgs` namespace bag of the selected
   * entry (e.g. `containerArgs.grid.column`). Placement edits are rarer than
   * typography edits, so we route directly through `replaceEntryContainerArgs`
   * (structural commit) rather than the keystroke-debounced `#pendingArgs`
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
   * Hard-navigates the editor onto a different theme by reloading the current
   * page with `?wf_theme=<id>`. A full document load is required (not an SPA
   * transition) so the boot preload re-seeds the new theme's block layouts and
   * per-theme metadata; the entry pill then auto-enters bound to it. Used after
   * duplicate / create-customization-component so the new owner takes effect and
   * Publish enables. Isolated here as a thin, stubbable seam.
   *
   * @param {number} themeId
   */
  navigateToEditTheme(themeId) {
    const url = new URL(window.location.href);
    url.searchParams.set("wf_theme", themeId);
    window.location.assign(url.toString());
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
   * The theme that owns an outlet (where Publish writes its live field) plus
   * the metadata needed to badge and gate it. For a published outlet the owner
   * is the theme that holds the field (the most-derived theme, resolved by the
   * core layer resolver); for a default/locked outlet nothing owns it yet, so
   * the target is this session's `activeThemeId` — the theme the editor was
   * entered against (an explicit `enter({ themeId })`) or, for the pill, the
   * current theme. `themeName` and `isGit` come from the per-theme metadata
   * preload.
   *
   * @param {string} outletName
   * @returns {{themeId: (number|null), themeName: (string|null), isGit: boolean, stackIndex: (number|undefined), layer: string}}
   */
  outletOwner(outletName) {
    const meta = this.blocks.resolvedLayoutMeta(outletName, {
      ignoreSessionDraft: true,
    });
    const themeId =
      meta?.source === LAYOUT_SOURCE.THEME
        ? Number(meta.sourceId)
        : (this.activeThemeId ?? this.defaultThemeId);
    const themeMeta = this.#themeMeta(themeId);
    return {
      themeId,
      themeName: themeMeta?.name ?? null,
      isGit: themeMeta?.is_git ?? false,
      stackIndex:
        meta?.source === LAYOUT_SOURCE.THEME
          ? meta.themeStackIndex
          : themeMeta?.stack_index,
      layer: meta?.source ?? null,
    };
  }

  /**
   * The edited outlets grouped by the theme that owns them — the publish plan.
   * Each group names its target theme and whether that theme can be published to
   * directly (a local, non-Git theme) or needs the companion/duplicate/export
   * path instead (a Git-managed or core "system" theme). Drives the publish
   * review surface and the toolbar target indicator.
   *
   * Reactive: derives from the engine's `editedOutletNames()` (which reads the
   * tracked edit bookkeeping) and `outletOwner` (which reads the tracked layer
   * store), so a template re-renders as edits and their owners change.
   *
   * @returns {Array<{themeId: (number|null), themeName: (string|null), isGit: boolean, isSystem: boolean, publishable: boolean, outlets: Array<string>}>}
   */
  get publishTargets() {
    const groups = new Map();
    for (const outletName of this.wireframeEditEngine.editedOutletNames()) {
      const owner = this.outletOwner(outletName);
      let group = groups.get(owner.themeId);
      if (!group) {
        const isSystem = owner.themeId != null && owner.themeId < 0;
        group = {
          themeId: owner.themeId,
          themeName: owner.themeName,
          isGit: owner.isGit,
          isSystem,
          publishable: !owner.isGit && !isSystem,
          outlets: [],
        };
        groups.set(owner.themeId, group);
      }
      group.outlets.push(outletName);
    }
    return [...groups.values()];
  }

  /**
   * The theme this session would publish to before anything is edited — the
   * theme the editor was entered against (or the default target). Used by the
   * toolbar target indicator to name the destination up front, with the same
   * `publishable` shape as a `publishTargets` group so the indicator can render
   * either uniformly. Null when no target can be resolved.
   *
   * @returns {{themeId: number, themeName: (string|null), isGit: boolean, isSystem: boolean, publishable: boolean}|null}
   */
  get activeThemeTarget() {
    const themeId = this.activeThemeId ?? this.defaultThemeId;
    if (themeId == null) {
      return null;
    }
    const themeMeta = this.#themeMeta(themeId);
    const isSystem = themeId < 0;
    const isGit = themeMeta?.is_git ?? false;
    return {
      themeId,
      themeName: themeMeta?.name ?? null,
      isGit,
      isSystem,
      publishable: !isGit && !isSystem,
    };
  }

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
    const after = this.layoutQuery.readResolvedLayout(outletName);
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
      this.layoutQuery.readResolvedLayout(outletName) ?? []
    );
    return JSON.stringify(layout, null, 2);
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
    this.dragSession.beginBlock({ blockKey, outletName });
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
    this.dragSession.beginPalette({ blockName, defaultArgs });
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
    this.dragSession.clear();
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
   * @param {string} blockKey
   * @returns {boolean}
   */
  isForceExpanded(blockKey) {
    return blockKey ? this.#forceExpandedKeys.has(blockKey) : false;
  }

  /**
   * Flips the force-expand state for a single `wf:layout` block. The
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
    if (this.#forceExpandedKeys.has(blockKey)) {
      this.#forceExpandedKeys.delete(blockKey);
    } else {
      this.#forceExpandedKeys.add(blockKey);
    }
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
    const source = this.layoutQuery.findEntryAndOutletSync(sourceKey);
    if (!source) {
      return false;
    }
    if (!this.dropAuthority.canDropAt({ targetOutletName })) {
      return false;
    }
    // An outlet-level drop (no target block) lands INSIDE the outlet's
    // implicit root layout, never as a sibling of it — that's what keeps the
    // "single root layout per outlet" invariant intact.
    if (targetKey == null) {
      this.ensureDraft(targetOutletName);
      targetKey = this.layoutQuery.outletRootKey(targetOutletName);
      position = "inside";
    }
    const outletsAffected =
      source.outletName === targetOutletName
        ? [source.outletName]
        : [source.outletName, targetOutletName];
    return this.recordStructural(outletsAffected, () => {
      const moved =
        source.outletName === targetOutletName
          ? this.#moveWithinOutlet(
              source.outletName,
              sourceKey,
              targetKey,
              position
            )
          : this.moveAcrossOutlets({
              sourceOutletName: source.outletName,
              targetOutletName,
              sourceEntry: source.entry,
              sourceKey,
              targetKey,
              position,
            });
      // Focus the moved block so it's the active selection afterwards — the
      // same treatment an inserted block gets. For a tabs / carousel child this
      // brings the moved tab or slide to the front via the reveal-on-select
      // path. A same-outlet move keeps the block's key; only select when the key
      // still resolves, so a cross-outlet re-key doesn't clear the selection.
      if (moved && this.layoutQuery.findEntryAndOutletSync(sourceKey)) {
        this.restoreSelection(sourceKey);
      }
      return moved;
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
   * `publishStructuralChange`) stamps a `__stableKey` when the draft
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
    if (!this.dropAuthority.canInsertBlockAt({ blockName, targetOutletName })) {
      return false;
    }
    return this.recordStructural([targetOutletName], () => {
      // Mint a draft on the fly for outlets the user is populating from
      // scratch (no published layout → `#materializeAllDrafts` skipped
      // them on `enter()`). The empty-outlet drop zone needs this.
      const layout = this.ensureDraft(targetOutletName);
      if (!layout) {
        return false;
      }
      // An outlet-level insert (no target block) lands INSIDE the outlet's
      // implicit root layout, preserving the single-root invariant. Resolved
      // after `ensureDraft` so a freshly-seeded outlet has its root key.
      if (targetKey == null) {
        targetKey = this.layoutQuery.outletRootKey(targetOutletName);
        position = "inside";
      }
      // Mint a fresh entry. Spread the defaults so future mutations don't
      // bleed back into the caller's object. Args left missing here get
      // filled in from the block's schema `default:` values via
      // `applyArgDefaults` at render time.
      const fresh = { block: blockName, args: { ...defaultArgs } };
      // A container that forces its children to one kind (e.g. tabs → `layout`)
      // must never be empty — it would be invalid AND have no first tab to fill.
      // Seed it with one child of that kind so dropping the block lands a ready
      // first panel (and the block's "add" affordance grows it from there).
      const seedKind = this.#implicitChildKind(blockName);
      if (seedKind) {
        fresh.children = [{ block: seedKind, args: {} }];
      }
      // Annotate with `containerArgs.grid` defaults when the destination
      // parent is a `wf:layout` in grid mode — that's the placement
      // namespace the grid layout reads to position each direct child.
      const entry = this.#annotateForDestination({
        entry: fresh,
        layout,
        targetKey,
        position,
      });
      const insertion = insertEntryAt(layout, targetKey, entry, position);
      if (!insertion.changed) {
        return false;
      }
      this.publishStructuralChange(targetOutletName, insertion.layout);
      // Auto-select the freshly inserted block so the inspector immediately
      // shows its form (and, for a `wf:layout` in grid mode, the grid overlay
      // mounts without the author having to click first).
      // `publishStructuralChange` runs `assignStableKeys`, so `entry`
      // has a `__stableKey` by the time this fires.
      this.selectInsertedEntry(entry);
      return true;
    });
  }

  /**
   * Appends a fresh child of a container's declared implicit-child kind to the
   * end of its children, then selects it. Drives the "add" affordance an
   * implicit-child-kind container renders (e.g. a tabbed container's trailing
   * "+" on the strip): the new panel is the sole `childBlocks` kind (a `layout`),
   * so it arrives ready to fill with a rich layout. No-ops for a key that isn't
   * such a container.
   *
   * @param {string} containerKey - The implicit-child-kind container's key.
   * @returns {boolean}
   */
  appendImplicitChild(containerKey) {
    const located = this.layoutQuery.findEntryAndOutletSync(containerKey);
    if (!located) {
      return false;
    }
    const kind = this.#implicitChildKind(located.entry.block);
    if (!kind) {
      return false;
    }
    return this.insertBlock({
      blockName: kind,
      targetKey: containerKey,
      position: "inside-end",
      targetOutletName: located.outletName,
    });
  }

  /**
   * The sole block kind a container forces every direct child to be (e.g. a
   * tabbed container → `layout`), or null when the block isn't such a container.
   * The kind must itself be a container, so a non-conforming child can be
   * wrapped in it and an empty container can be seeded with it.
   *
   * @param {string|Function} blockRef - The container's block ref.
   * @returns {string|null}
   */
  #implicitChildKind(blockRef) {
    const childBlocks =
      this.layoutQuery.lookupBlockMetadata(blockRef)?.childBlocks;
    if (childBlocks?.length !== 1) {
      return null;
    }
    const kind = childBlocks[0];
    return this.layoutQuery.lookupBlockMetadata(kind)?.isContainer
      ? kind
      : null;
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
   * @param {Object} request - See `GridManipulator#drop`.
   * @returns {boolean}
   */
  @action
  applyGridDrop(request) {
    return this.gridManipulator.drop(request);
  }

  /**
   * Returns the slot children of a grid `wf:layout` whose explicit
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
    const located = this.layoutQuery.findEntryAndOutletSync(gridKey);
    if (!located || !this.layoutQuery.isGridContainer(located.entry)) {
      return [];
    }
    const offenders = [];
    for (const slot of located.entry.children ?? []) {
      if (!this.layoutQuery.isGridCellEntry(slot)) {
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
    const located = this.layoutQuery.findEntryAndOutletSync(gridKey);
    if (!located || !this.layoutQuery.isGridContainer(located.entry)) {
      return false;
    }
    const offenders = this.outOfBoundsSlotsIn(gridKey, maxColumns, maxRows);
    if (offenders.length === 0) {
      return false;
    }
    return this.recordStructural([located.outletName], () => {
      for (const slot of located.entry.children ?? []) {
        if (!this.layoutQuery.isGridCellEntry(slot)) {
          continue;
        }
        const placement = parsePlacement(slot.containerArgs);
        const newColumn = this.#clampTrack(placement.column, maxColumns);
        const newRow = this.#clampTrack(placement.row, maxRows);
        if (newColumn == null && newRow == null) {
          continue;
        }
        const layout = this.layoutQuery.readResolvedLayout(located.outletName);
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
        this.publishStructuralChange(located.outletName, result.layout);
      }
      return true;
    });
  }

  /**
   * Applies a preset grid template to an existing `wf:layout` block.
   * The template resolves to an ordered list of cells (its declared
   * rects). Existing content is reflowed into those cells in reading
   * order; a block dropped into a spanning cell adopts the span.
   * Leftover spanning cells become empty merged-cell entries; leftover
   * single cells are surfaced by the grid overlay. The only refusal is
   * "more content than the template has room for", so switching between
   * templates stays free as long as the content fits — no template
   * disables another just by being applied.
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
    const located = this.layoutQuery.findEntryAndOutletSync(gridKey);
    if (!located) {
      return false;
    }
    const { args: templateArgs, slotEntries } = resolveTemplateLayout(template);
    const cells = this.#cellsFor(templateArgs, slotEntries);
    const content = this.#contentChildren(located.entry);
    // More content than the template can hold: refuse before mutating.
    if (content.length > cells.length) {
      return false;
    }
    return this.recordStructural([located.outletName], () => {
      const layout = this.layoutQuery.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const result = replaceEntryInPlace(layout, gridKey, {
        ...located.entry,
        // Drop any resized `columnFractions` — the new shape defines its
        // own (even) tracks.
        args: { ...located.entry.args, ...templateArgs, columnFractions: [] },
        children: this.#reflowIntoCells(content, cells),
      });
      if (!result.changed) {
        return false;
      }
      this.publishStructuralChange(located.outletName, result.layout);
      return true;
    });
  }

  /**
   * Returns `true` when `applyGridTemplate` would succeed for the given
   * template against the currently-selected `wf:layout` — i.e. the
   * layout's content fits the template's number of cells. Pure-read;
   * the inspector calls this to disable a template option that can't
   * hold the current content. Mirrors the refusal predicate inside
   * `applyGridTemplate`.
   *
   * @param {{gridKey: string, template: Object}} args
   * @returns {boolean}
   */
  canApplyGridTemplate({ gridKey, template }) {
    if (!template) {
      return false;
    }
    const located = this.layoutQuery.findEntryAndOutletSync(gridKey);
    if (!located) {
      return false;
    }
    const { args: templateArgs, slotEntries } = resolveTemplateLayout(template);
    const cells = this.#cellsFor(templateArgs, slotEntries);
    return this.#contentChildren(located.entry).length <= cells.length;
  }

  /**
   * The preset template whose shape matches the given grid's current
   * shape, or `null` when it matches none (which the inspector reads as
   * "Free"). Pure-read; drives the inspector's Free / Template control
   * and the active-preset highlight. Derived from geometry rather than a
   * stored id, so it never goes stale against hand edits.
   *
   * @param {string} gridKey
   * @returns {Object|null}
   */
  activeGridTemplate(gridKey) {
    const located = this.layoutQuery.findEntryAndOutletSync(gridKey);
    if (!located) {
      return null;
    }
    const { columns, rows } = this.gridSizeFor(gridKey);
    return matchGridTemplate(located.entry.children ?? [], columns, rows);
  }

  /**
   * The effective `{columns, rows}` of a grid layout — the larger of its
   * declared args and what its children occupy (see core's
   * `gridDimensions`). The inspector reads this for its column / row
   * fields and for shape-matching, so the displayed size always matches
   * the rendered grid rather than a bare default that can drift.
   *
   * @param {string} gridKey
   * @returns {{columns: number, rows: number}}
   */
  gridSizeFor(gridKey) {
    const located = this.layoutQuery.findEntryAndOutletSync(gridKey);
    const args = located?.entry.args ?? {};
    return gridDimensions(
      {
        columns: args.columns ?? DEFAULT_GRID_COLUMNS,
        rows: args.rows ?? DEFAULT_GRID_ROWS,
      },
      located?.entry.children
    );
  }

  /**
   * Switches a `wf:layout` into free mode at the given dimensions: the
   * grid becomes `columns × rows` single cells and existing content is
   * reflowed into them in reading order. This is the "Free" counterpart
   * to `applyGridTemplate` — picking Free, or changing the column / row
   * count while in Free, both route here so blocks rearrange to fit
   * rather than spilling out of bounds. Refuses when there's more
   * content than `columns × rows` cells.
   *
   * @param {{gridKey: string, columns: number, rows: number}} args
   * @returns {boolean}
   */
  @action
  applyFreeGrid({ gridKey, columns, rows }) {
    const located = this.layoutQuery.findEntryAndOutletSync(gridKey);
    if (!located) {
      return false;
    }
    const cells = cellsForFree(columns, rows);
    const content = this.#contentChildren(located.entry);
    if (content.length > cells.length) {
      return false;
    }
    return this.recordStructural([located.outletName], () => {
      const layout = this.layoutQuery.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const result = replaceEntryInPlace(layout, gridKey, {
        ...located.entry,
        // Free mode is even tracks — drop any resized `columnFractions`.
        args: {
          ...located.entry.args,
          mode: "grid",
          columns,
          rows,
          columnFractions: [],
        },
        children: this.#reflowIntoCells(content, cells),
      });
      if (!result.changed) {
        return false;
      }
      this.publishStructuralChange(located.outletName, result.layout);
      return true;
    });
  }

  /**
   * The layout entry's content children — everything except the empty
   * merged-cell placeholders, which are regenerated by the reflow rather
   * than carried across.
   *
   * @param {Object} entry
   * @returns {Array<Object>}
   */
  #contentChildren(entry) {
    return contentCells(entry.children);
  }

  /**
   * The ordered list of target cells for a template's resolved args.
   * A template with declared areas hands back its rects; a frame-only
   * preset (no areas) fills every cell of its grid.
   *
   * @param {Object} templateArgs
   * @param {Array<Object>} slotEntries
   * @returns {Array<{column: string, row: string}>}
   */
  #cellsFor(templateArgs, slotEntries) {
    if (slotEntries.length > 0) {
      return slotEntries.map((entry) => ({
        column: entry.containerArgs.grid.column,
        row: entry.containerArgs.grid.row,
      }));
    }
    return cellsForFree(templateArgs.columns ?? 3, templateArgs.rows ?? 1);
  }

  /**
   * Reflows `content` into `cells`, with a container-validity guard: a
   * grid must have at least one child, but the reflow leaves single
   * empty cells derived (no entry). When the result would be empty (no
   * content and only single cells), materialise every cell as an empty
   * merged cell so the grid keeps a body and shows its shape.
   *
   * @param {Array<Object>} content
   * @param {Array<{column: string, row: string}>} cells
   * @returns {Array<Object>}
   */
  #reflowIntoCells(content, cells) {
    const reflowed = reflowChildrenIntoCells(content, cells);
    if (reflowed && reflowed.length > 0) {
      return reflowed;
    }
    return cells.map((cell) => ({
      block: LAYOUT_MERGED_CELL_BLOCK,
      containerArgs: {
        grid: {
          column: cell.column,
          row: cell.row,
          align: "stretch",
          justify: "stretch",
        },
      },
    }));
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
    return this.gridManipulator.moveIntoCell(args);
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
    return this.gridManipulator.placeInCell(args);
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
   * Detaches the selected composite: materialises its code-defined parts (with
   * current overrides) into explicit `children` and drops the override map, so
   * it becomes a plain container the author can restructure. Peels exactly one
   * layer — a composite child stays composed. Structural commit (undo/redo +
   * draft re-publish). Manual only; never automatic.
   *
   * @returns {boolean}
   */
  @action
  detachSelectedComposite() {
    const key = this.selectedBlockKey;
    if (!key) {
      return false;
    }
    const located = this.layoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return false;
    }
    return this.recordStructural([located.outletName], () => {
      const layout = this.layoutQuery.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const result = detachComposite(layout, key);
      if (!result.changed) {
        return false;
      }
      this.publishStructuralChange(located.outletName, result.layout);
      return true;
    });
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
   * Window-level `dragover` / `drop` guard. Without this, the browser's
   * default behaviour for an external file drag is to NAVIGATE to the
   * dropped file when the user releases over any element that didn't
   * call `event.preventDefault()`. Per-overlay drop handlers can't
   * always reach their stopPropagation in time (e.g. if the user
   * releases over the chrome outside an image marker), and the
   * resulting full-page navigation throws the editor session away.
   *
   * The guard fires only while the editor is active and the drag
   * carries files. It always calls `preventDefault` so the browser
   * never gets to navigate; specific overlay handlers still receive
   * the event via normal DOM bubbling and route uploads as needed.
   */
  #installFileDragGuard() {
    if (typeof window === "undefined") {
      return;
    }
    this._handleFileDragOver = (event) => {
      if (!this.isActive) {
        return;
      }
      if (!event.dataTransfer?.types?.includes?.("Files")) {
        return;
      }
      event.preventDefault();
    };
    this._handleFileDrop = (event) => {
      if (!this.isActive) {
        return;
      }
      if (!event.dataTransfer?.types?.includes?.("Files")) {
        return;
      }
      event.preventDefault();
      // Safety net for external (file) drags, which have no element source
      // modifier to run `endDrag`: this bubbling-phase listener fires after
      // PDND's capture-phase target `onDrop` (which already dispatched), so
      // clearing the overlay here can't wipe an unconsumed dispatch.
      this.wireframeDragOverlay.clear();
    };
    window.addEventListener("dragover", this._handleFileDragOver, false);
    window.addEventListener("drop", this._handleFileDrop, false);
  }

  #uninstallFileDragGuard() {
    if (this._handleFileDragOver) {
      window.removeEventListener("dragover", this._handleFileDragOver, false);
      this._handleFileDragOver = null;
    }
    if (this._handleFileDrop) {
      window.removeEventListener("drop", this._handleFileDrop, false);
      this._handleFileDrop = null;
    }
  }

  /**
   * Installs a window-level `paste` listener that routes image data
   * from the system clipboard into the selected block's image arg. The
   * listener is always installed (it's cheap and only acts when a
   * block with image args is selected), and torn down when the
   * service is destroyed.
   *
   * Guarded so the handler ignores pastes that originate inside
   * native text inputs / contenteditables outside the editor — those
   * keep their default browser behaviour.
   */
  #installImagePasteListener() {
    if (typeof document === "undefined") {
      return;
    }
    this._handleImagePaste = (event) => {
      this.#onImagePaste(event);
    };
    document.addEventListener("paste", this._handleImagePaste, true);
  }

  #uninstallImagePasteListener() {
    if (this._handleImagePaste) {
      document.removeEventListener("paste", this._handleImagePaste, true);
      this._handleImagePaste = null;
    }
  }

  /**
   * Paste handler. No-ops unless all of:
   *   - A block is selected on the canvas
   *   - That block declares one or more image args
   *   - The clipboard carries at least one image file
   *   - The paste target isn't a text input outside the editor scope
   *
   * When everything lines up, the handler picks the target arg
   * (`lastTouchedImageArg` if set and still valid, else the first
   * image arg declared on the block) and routes the file through the
   * shared upload helper.
   *
   * @param {ClipboardEvent} event
   */
  async #onImagePaste(event) {
    const blockKey = this.selectedBlockKey;
    if (!blockKey) {
      return;
    }
    const imageArgs = imageArgEntries(
      this.selectedBlockData?.metadata?.args
    ).map((entry) => entry.name);
    if (imageArgs.length === 0) {
      return;
    }
    if (this.#pasteTargetIsTextInput(event.target)) {
      return;
    }
    const file = this.#pickImageFromClipboard(event.clipboardData);
    if (!file) {
      return;
    }
    event.preventDefault();

    const argName =
      this.lastTouchedImageArg && imageArgs.includes(this.lastTouchedImageArg)
        ? this.lastTouchedImageArg
        : imageArgs[0];

    await this.uploadImageForArg(file, { blockKey, argName });
  }

  /**
   * Returns `true` when the paste's `event.target` is a native text
   * surface (input, textarea, contenteditable) that isn't part of the
   * editor's own chrome — in which case the native paste behaviour
   * (insert text / image into the field) is the expected outcome and
   * we shouldn't hijack it.
   *
   * Inputs INSIDE the editor chrome (e.g. an inspector field) are
   * also skipped — the inspector already has its own image controls.
   *
   * @param {EventTarget|null} target
   * @returns {boolean}
   */
  #pasteTargetIsTextInput(target) {
    if (!(target instanceof Element)) {
      return false;
    }
    if (target.closest("input, textarea, [contenteditable]")) {
      return true;
    }
    return false;
  }

  /**
   * Pulls the first image File out of a clipboard payload. Falls back
   * to `items` (where the file representation lives in some browsers
   * for image-only pastes) when `files` is empty.
   *
   * @param {DataTransfer|null|undefined} clipboardData
   * @returns {File|null}
   */
  #pickImageFromClipboard(clipboardData) {
    if (!clipboardData) {
      return null;
    }
    if (clipboardData.files?.length) {
      for (const f of clipboardData.files) {
        if (f.type?.startsWith("image/")) {
          return f;
        }
      }
    }
    if (clipboardData.items?.length) {
      for (const item of clipboardData.items) {
        if (item.kind === "file" && item.type?.startsWith("image/")) {
          const file = item.getAsFile();
          if (file) {
            return file;
          }
        }
      }
    }
    return null;
  }

  /**
   * Hydrates the conditions panel state from localStorage on service
   * init. Tolerates missing / malformed entries by leaving the
   * defaults in place.
   */
  #loadConditionsPanelState() {
    try {
      const raw = localStorage.getItem("wireframe.conditions-panel");
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

  #persistConditionsPanelState() {
    try {
      localStorage.setItem(
        "wireframe.conditions-panel",
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
   * Picks a default theme id for editor sessions that didn't supply one (the
   * pill entry, vs. an explicit `enter({ themeId })`). This is the theme the
   * page actually renders against — the parent of the active stack, which is
   * `stack_index 0` in `Theme.transform_ids` — so edits to an outlet nothing
   * owns yet save back to the current theme.
   *
   * Derived from the `themeBlockLayoutMeta` preload, which carries each stack
   * theme's `stack_index` and includes seeded default themes (negative ids like
   * Foundation `-1`). NOT from `activatedThemes`: that is an unordered
   * `{ id: name }` map, and a numeric-key lookup would both lose the stack order
   * and skip the negative-id parent.
   *
   * Falls back to the user-selectable themes list when the meta preload is
   * unavailable or empty. Returns null when no themes are available, in which
   * case the Save / Publish control stays disabled.
   *
   * @returns {number|null}
   */
  #defaultThemeId() {
    const meta = PreloadStore.get("themeBlockLayoutMeta");
    if (meta && typeof meta === "object") {
      let parentId = null;
      let minRank = Infinity;
      for (const [id, info] of Object.entries(meta)) {
        const rank = info?.stack_index ?? Infinity;
        if (rank < minRank) {
          minRank = rank;
          parentId = Number(id);
        }
      }
      if (parentId != null) {
        return parentId;
      }
    }
    const themes = this.site?.user_themes ?? [];
    return (
      themes.find((t) => t.default)?.theme_id ?? themes[0]?.theme_id ?? null
    );
  }

  /**
   * Per-theme metadata from the boot preload (display name, git status, stack
   * rank), keyed by theme id. The preload is JSON, so its keys are strings;
   * coerce the lookup id to a string. Returns null when the theme is absent.
   *
   * @param {number|string|null} themeId
   * @returns {?{name: string, component: boolean, is_git: boolean, stack_index: number}}
   */
  #themeMeta(themeId) {
    if (themeId == null) {
      return null;
    }
    const meta = PreloadStore.get("themeBlockLayoutMeta");
    if (!meta || typeof meta !== "object") {
      return null;
    }
    return meta[String(themeId)] ?? null;
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
      this.activeThemeId = companionId;
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
      this.#pendingArgs.size === 0 &&
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
   * Recursively walks `entries` and pushes one `{outletName, message}`
   * warning for every entry carrying a `__failureReason` stamp. Reads
   * `__failureReason` rather than the truthy stamp pair (`__failureType`
   * is also set) because the message is what the UI surfaces.
   *
   * @param {Array<Object>} entries
   * @param {string} outletName
   * @param {Array<{outletName: string, message: string}>} warnings
   */
  #collectStampedWarnings(entries, outletName, warnings) {
    for (const entry of entries) {
      if (entry?.__failureReason) {
        warnings.push({ outletName, message: entry.__failureReason });
      }
      if (entry?.children?.length) {
        this.#collectStampedWarnings(entry.children, outletName, warnings);
      }
    }
  }

  /**
   * Returns true when removing `entry` from `layout` should leave an
   * empty merged-cell entry at the same position instead of clearing
   * the cell entirely. All four conditions must hold:
   *
   *   1. The entry isn't already a merged cell — deleting an empty cell
   *      is the author saying "I don't want this region", not
   *      "regenerate one".
   *   2. The placement spans more than one cell (column span > 1 OR
   *      row span > 1). Single-cell positions are already discoverable
   *      via the grid overlay's auto-empty cell rendering; we only
   *      need an explicit cell entry when the rect is too large for
   *      the auto-detection to reconstruct.
   *   3. The placement fits within the parent grid's `columns` /
   *      `rows`. Restoring a cell that overflows the grid would just
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
  #shouldRestoreAsCell(layout, entry, entryKeyValue) {
    if (!entry || isMergedCell(entry)) {
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
   * Applies every pending arg change in one shot by mutating the resolved
   * entry's `args` directly. The block's reactive getters propagate the
   * change through Glimmer's autotracking — no layout swap, no DOM
   * tear-down, no inspector remount.
   *
   * Captures the pre-edit snapshot BEFORE applying the mutation so reset /
   * exit / undo have the original state to restore. Records the affected
   * outlet in `editedOutlets` so persistence knows what to POST on Save.
   *
   * @returns {Promise<boolean>} True if the flush touched an entry.
   */
  async #flushPendingArgs() {
    const key = this.selectedBlockKey;
    if (!key || this.#pendingArgs.size === 0) {
      return false;
    }
    const pending = [...this.#pendingArgs.entries()];
    this.#pendingArgs.clear();

    // A selected composite part has no persisted entry: its edits are written
    // to the owning composite's per-part override map (a structural commit),
    // not into a tracked entry's args.
    const partContext = this.layoutQuery.resolvePartContext(key);
    if (partContext) {
      return this.#flushPendingPartArgs(partContext, pending);
    }

    const located = await this.layoutQuery.findEntryAndOutlet(key);
    if (!located) {
      return false;
    }
    const { entry, outletName } = located;

    const prevMap = new Map();
    for (const [argName] of pending) {
      prevMap.set(argName, entry.args?.[argName]);
    }

    // The engine flags the outlet, captures the FULL pre-edit snapshot before
    // applying the mutation (so reset / exit have a complete rollback target),
    // writes the new values, and pushes a single `args` undo entry.
    this.wireframeEditEngine.recordArgBatch({
      entry,
      outletName,
      prevMap,
      nextMap: new Map(pending),
    });

    return true;
  }

  /**
   * Commits a batch of pending arg edits for a selected composite part by
   * merging them into the owning composite entry's per-part override map. This
   * is a structural commit (the synthesis reads `entry.overrides` at render
   * time, and synthesized part args aren't tracked objects), so it routes
   * through `recordStructural` for undo/redo and re-publishes the draft layer.
   * Setting an arg to `null`/`undefined` removes it from the override (reverting
   * that arg to the part's code default).
   *
   * @param {{compositeKey: string, outletName: string, partPath: string}} partContext
   * @param {Array<[string, *]>} pending
   * @returns {boolean}
   */
  #flushPendingPartArgs({ compositeKey, outletName, partPath }, pending) {
    return this.recordStructural([outletName], () => {
      const layout = this.layoutQuery.readResolvedLayout(outletName);
      if (!layout) {
        return false;
      }
      const result = setPartOverride(
        layout,
        compositeKey,
        partPath,
        (current) => {
          const merged = { ...current };
          for (const [argName, value] of pending) {
            if (value == null) {
              delete merged[argName];
            } else {
              merged[argName] = value;
            }
          }
          return merged;
        }
      );
      if (!result.changed) {
        return false;
      }
      this.publishStructuralChange(outletName, result.layout);
      return true;
    });
  }

  /**
   * Looks up the composite key of a freshly inserted entry (after
   * `publishStructuralChange` has assigned its `__stableKey`) and routes
   * through `restoreSelection` so the editor's selection state — and the
   * inspector — points at it. No-ops if the entry isn't yet resolvable
   * (paranoia: the assign should always succeed for a just-inserted entry).
   *
   * @param {Object} entry - The original entry reference passed into the
   *   layout; will have its `__stableKey` set by the publish step.
   */
  selectInsertedEntry(entry) {
    const key = entryKey(entry);
    if (!key) {
      return;
    }
    this.restoreSelection(key);
    // Flash the freshly inserted block so the eye lands on it, the same way
    // outline selection does.
    this.#blockReveal.flash(key);
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
  #clampTrack(track, max) {
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

  #moveWithinOutlet(
    outletName,
    sourceKey,
    targetKey,
    position,
    { syncGridOrder = true, placeEntering = true } = {}
  ) {
    const layout = this.layoutQuery.readResolvedLayout(outletName);
    if (!layout) {
      return false;
    }
    const sourceEntry = findEntry(layout, sourceKey);
    if (!sourceEntry) {
      return false;
    }

    // Classify the move against the destination grid (if any). A grid
    // ENTER is a move whose destination grid is NOT the source's current
    // parent; a same-grid move keeps the source under the same grid.
    const sourceParentKey = this.#parentKeyOf(layout, sourceKey);
    const destGridKey = this.#destinationGridKey(layout, targetKey, position);
    const enteringGrid = destGridKey != null && destGridKey !== sourceParentKey;
    const sameGrid = destGridKey != null && destGridKey === sourceParentKey;
    const besideCell =
      (position === "before" || position === "after") &&
      targetKey != null &&
      targetKey !== destGridKey;

    // A drop BESIDE a cell — whether the block is entering or already in
    // this grid — cascades the row to make room (R2: shift right, grow a
    // column when the row is full). Same-grid cascades in place: grids
    // position by `containerArgs.grid`, not array order, so no remove /
    // insert is needed. `gridManipulator.positionEntering` routes through the
    // decider, so same-grid and entering cascades share one rule path.
    // `placeEntering: false` callers set an exact cell themselves and opt out.
    if (sameGrid && besideCell && placeEntering) {
      this.publishStructuralChange(
        outletName,
        this.gridManipulator.positionEntering(
          layout,
          destGridKey,
          sourceKey,
          targetKey,
          position
        )
      );
      return true;
    }

    // Other same-grid moves (dropped on the grid container itself, not a
    // specific cell): keep the reading-order reflow so the array order
    // drives the visual order.
    if (sameGrid) {
      const result = moveEntry(layout, sourceKey, targetKey, position);
      if (!result.changed) {
        return false;
      }
      this.publishStructuralChange(
        outletName,
        syncGridOrder
          ? this.#syncDestGridOrder(result.layout, targetKey, position)
          : result.layout
      );
      return true;
    }

    // Any other move: the destination may require resetting the grid bag
    // (entering a grid — a carried span is discarded) OR stripping it
    // (leaving a grid). Both substitute the entry, so a remove + insert is
    // needed — which also guarantees the source is removed.
    const transformed = this.#transformForDestination({
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
      const insertion = insertEntryAt(
        removal.layout,
        targetKey,
        transformed,
        position
      );
      if (!insertion.changed) {
        return false;
      }
      // A block entering a grid claims a valid single cell (next free
      // slot, growing a row when full) and the grid's declared size is
      // synced to usage — never the array-order reflow, which is for
      // reorders within a grid. Callers that set an exact cell afterward
      // (the precise cell-drop path) opt out via `placeEntering: false`.
      const finalLayout =
        enteringGrid && placeEntering
          ? this.gridManipulator.positionEntering(
              insertion.layout,
              destGridKey,
              sourceKey,
              targetKey,
              position
            )
          : insertion.layout;
      this.publishStructuralChange(outletName, finalLayout);
      return true;
    }
    const result = moveEntry(layout, sourceKey, targetKey, position);
    if (!result.changed) {
      return false;
    }
    this.publishStructuralChange(
      outletName,
      syncGridOrder
        ? this.#syncDestGridOrder(result.layout, targetKey, position)
        : result.layout
    );
    return true;
  }

  /**
   * The composite key of the `wf:layout` (grid mode) that would CONTAIN an
   * entry dropped at `(targetKey, position)`, or `null` when the
   * destination isn't a grid. "inside" targets the container itself;
   * "before" / "after" target a sibling, so the grid is its parent.
   *
   * @param {Array<Object>} layout
   * @param {string|null} targetKey
   * @param {"before"|"after"|"inside"} position
   * @returns {string|null}
   */
  #destinationGridKey(layout, targetKey, position) {
    const parent = this.#destinationParentEntry({
      layout,
      targetKey,
      position,
    });
    return this.layoutQuery.isGridContainer(parent) ? entryKey(parent) : null;
  }

  /**
   * When a within-outlet move lands in a grid layout, re-derive that
   * grid's content placements from the new array order (see
   * `syncContentToArrayOrder`) so reordering rows in the outline moves
   * blocks in the grid rather than just shuffling an invisible array.
   * A no-op for stack / row destinations, where array order already IS
   * the visual order.
   *
   * @param {Array<Object>} layout
   * @param {string} targetKey - The move's target (sibling for
   *   before / after, the container itself for inside).
   * @param {"before"|"after"|"inside"} position
   * @returns {Array<Object>} The layout, with the destination grid's
   *   content resynced when applicable.
   */
  #syncDestGridOrder(layout, targetKey, position) {
    const gridKey =
      position === "inside" ? targetKey : this.#parentKeyOf(layout, targetKey);
    if (!gridKey) {
      return layout;
    }
    const grid = findEntry(layout, gridKey);
    if (!grid || grid.args?.mode !== "grid") {
      return layout;
    }
    const result = replaceEntryInPlace(layout, gridKey, {
      ...grid,
      children: syncContentToArrayOrder(grid.children ?? []),
    });
    return result.changed ? result.layout : layout;
  }

  /**
   * The composite key of `key`'s parent entry, or `null` when `key` is
   * top-level (no enclosing container) or can't be found.
   *
   * @param {Array<Object>} layout
   * @param {string} key
   * @returns {string|null}
   */
  #parentKeyOf(layout, key) {
    const chain = findAncestryPath(layout, key);
    if (!chain || chain.length < 2) {
      return null;
    }
    return entryKey(chain[chain.length - 2]);
  }

  moveAcrossOutlets({
    sourceOutletName,
    targetOutletName,
    sourceKey,
    targetKey,
    position,
    autoPosition = true,
  }) {
    // SAME outlet: the removal and the insertion MUST compose on one
    // layout. Reading the source and target outlets as two separate
    // copies (the cross-outlet path below) would insert into a copy that
    // still holds the not-yet-removed source — duplicating the block. This
    // path is reached when a grid cell is dragged into a DIFFERENT grid in
    // the same outlet (e.g. via a cross-grid drop).
    if (sourceOutletName === targetOutletName) {
      const layout = this.layoutQuery.readResolvedLayout(sourceOutletName);
      if (!layout) {
        return false;
      }
      const removal = removeEntry(layout, sourceKey);
      if (!removal.changed || !removal.removed) {
        return false;
      }
      const entryToInsert = this.#transformForDestination({
        entry: removal.removed,
        layout: removal.layout,
        targetKey,
        position,
      });
      const insertion = insertEntryAt(
        removal.layout,
        targetKey,
        entryToInsert,
        position
      );
      if (!insertion.changed) {
        return false;
      }
      const destGridKey = this.#destinationGridKey(
        insertion.layout,
        targetKey,
        position
      );
      const final =
        autoPosition && destGridKey
          ? this.gridManipulator.positionEntering(
              insertion.layout,
              destGridKey,
              sourceKey,
              targetKey,
              position
            )
          : insertion.layout;
      this.publishStructuralChange(sourceOutletName, final);
      return true;
    }

    const sourceLayout = this.layoutQuery.readResolvedLayout(sourceOutletName);
    // Mint a draft for the target outlet if it doesn't have one yet —
    // the user may be dragging an existing block into a previously
    // empty outlet via the empty-outlet drop zone.
    const targetLayout = this.ensureDraft(targetOutletName);
    if (!sourceLayout || !targetLayout) {
      return false;
    }
    const removal = removeEntry(sourceLayout, sourceKey);
    if (!removal.changed || !removal.removed) {
      return false;
    }
    // The moved entry may need to be wrapped (non-slot landing in a
    // grid) OR unwrapped (slot landing in a non-grid). Both cases
    // funnel through `#transformForDestination`.
    const entryToInsert = this.#transformForDestination({
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
    // A cross-outlet move is always a grid ENTER when the destination is a
    // grid: claim a valid single cell and sync the grid's declared size.
    const destGridKey = this.#destinationGridKey(
      insertion.layout,
      targetKey,
      position
    );
    const targetFinal =
      autoPosition && destGridKey
        ? this.gridManipulator.positionEntering(
            insertion.layout,
            destGridKey,
            sourceKey,
            targetKey,
            position
          )
        : insertion.layout;
    // Publish both outlets in one go — the editor service holds both as
    // session-draft layers, so each `_setLayoutLayer` call only re-resolves
    // its own outlet's chain.
    this.publishStructuralChange(sourceOutletName, removal.layout);
    this.publishStructuralChange(targetOutletName, targetFinal);
    return true;
  }

  /**
   * Annotates an entry with `containerArgs.grid` defaults when its
   * destination parent is a `wf:layout` in `grid` mode. The grid
   * namespace carries CSS Grid placement (`column` / `row` / `align` /
   * `justify`) so the layout can position each direct child.
   *
   * Returns the entry to insert. When no annotation is needed
   * (destination isn't a grid) returns the entry unchanged.
   *
   * A block ENTERING a grid always has its `grid` namespace reset to a
   * neutral `auto / auto` cell — any span/placement it carried from a
   * previous grid is discarded, so it can never drag a stale wide span
   * into a smaller grid. The concrete cell it occupies is assigned by the
   * caller (`#placeEntering`) once the children + dimensions are known;
   * this only guarantees the foreign placement is gone. The returned
   * object is always a fresh reference, so the caller's
   * `transformed !== sourceEntry` check routes through remove + insert
   * (which guarantees the source is removed). Same-grid reorders never
   * reach here — the movers handle those before transforming.
   *
   * @param {{entry: Object, layout: Array<Object>, targetKey: string|null, position: string}} args
   * @returns {Object}
   */
  #annotateForDestination({ entry, layout, targetKey, position }) {
    if (!entry) {
      return entry;
    }
    const parent = this.#destinationParentEntry({
      layout,
      targetKey,
      position,
    });
    const enteringGrid = this.layoutQuery.isGridContainer(parent);

    if (enteringGrid) {
      // Overwrite (don't merge) the grid bag so a carried span is dropped.
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
  #transformForDestination({ entry, layout, targetKey, position }) {
    return this.#annotateForDestination({ entry, layout, targetKey, position });
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
  #destinationParentEntry({ layout, targetKey, position }) {
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
}
