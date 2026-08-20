import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { trackedSet } from "@ember/reactive/collections";
import Service, { service } from "@ember/service";
import type { BlockMetadata, LayoutEntry } from "discourse/blocks/types";
import type { ValidationErrorDetails } from "discourse/lib/blocks/-internals/validation/args";
import {
  entryKey,
  findAncestryPath,
  findEntry,
  findEntrySiblings,
  resolvePartDef,
  serializeEntryForSave,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";
import { inferSchemaFromValues } from "discourse/plugins/discourse-wireframe/discourse/lib/layout/schema-to-fields";
import type WireframeEditModeService from "./wireframe-edit-mode";
import type WireframeLayoutQueryService from "./wireframe-layout-query";
import type WireframeLayoutSignalService from "./wireframe-layout-signal";

/**
 * A `LayoutEntry` widened with the runtime-only fields the permissive-mode
 * validation path stamps onto an entry. These are attached during validation
 * (never authored in a layout), so they live in a local extension rather than
 * on the shared `LayoutEntry`. They mirror the soft-failure shape the
 * validation layer writes.
 */
// TODO(devxp-typescript-pending): use the core resolved-entry type once it
// includes the runtime validation stamps produced by permissive rendering.
type ValidatedEntry = LayoutEntry & {
  /** The failure category recognised by the ghost-rendering path. */
  __failureType?: string;

  /** The human-readable failure message. */
  __failureReason?: string;

  /** The structured, accumulated failure details for per-field display. */
  __failureDetails?: ValidationErrorDetails[];
};

/**
 * Views a resolved layout entry through the permissive validation stamps that
 * core attaches at runtime.
 *
 * @param entry - Resolved entry that may carry validation stamps.
 * @returns The same entry with the runtime validation fields exposed.
 */
function validatedEntry(
  entry: LayoutEntry | undefined
): ValidatedEntry | undefined {
  // TODO(devxp-typescript-pending): remove this cast once core's resolved-entry
  // type includes the permissive validation stamps attached at runtime.
  return entry as ValidatedEntry | undefined;
}

/**
 * The selection payload passed to `selectBlock` and stored in
 * `selectedBlockData`. A loose subset of a resolved entry: programmatic callers
 * (drag-and-drop auto-select, command-palette, tests) may pass only `{ key }`,
 * and `selectBlock` hydrates the rest from the live layout. The trailing
 * snapshot fields are derived at selection time so the inspector's forms bind
 * to stable plain objects across a live keystroke session.
 */
export interface SelectedBlockData {
  /** The composite block key (`${name}:${__stableKey}`), or `null`. */
  key: string | null;

  /** The block's registered name. */
  name?: string | null;

  /** The block's optional DOM/styling id. */
  id?: string;

  /** The LIVE `entry.args` reference (a `trackedObject`) once hydrated. */
  args?: Record<string, unknown> | null;

  /** The block's placement values in its parent's `childArgs` namespaces. */
  containerArgs?: Record<string, unknown> | null;

  /** The block's render conditions tree. */
  conditions?: object | object[] | null;

  /** Outlet-level args, only set when the selection comes from the canvas. */
  outletArgs?: Record<string, unknown> | null;

  /** The name of the outlet the block lives in. */
  outletName?: string | null;

  /**
   * The block's editor metadata. A partial view because `#withInferredMetadata`
   * can synthesise one (with an inferred `args` schema) for blocks that declare
   * no schema of their own.
   */
  metadata?: Partial<BlockMetadata> | null;

  /** A plain snapshot of `args` handed to the inspector's `<Form @data>`. */
  argsSnapshot?: Record<string, unknown>;

  /** A per-namespace plain snapshot of `containerArgs` for the placement form. */
  containerArgsSnapshot?: Record<string, unknown>;

  /** The parent's `childArgs` schema, for the inspector's placement section. */
  parentChildArgsSchema?: BlockMetadata["childArgs"];

  /** A plain snapshot of the parent's `args`, for conditional-field evaluation. */
  parentArgsSnapshot?: Record<string, unknown>;

  /** Whether the editor recognises this block type. */
  isRegistered?: boolean;
}

/**
 * One segment of the selected block's ancestry path, from the outlet root down
 * to the block itself. Consumed by the canvas-bottom breadcrumb. The outlet
 * segment is first (`isOutlet: true`, `key: null`), nested containers follow,
 * and the selected block is last.
 */
export interface BlockAncestrySegment {
  /** Composite key of the block, or `null` for the outlet segment. */
  key: string | null;
  /** Registered block name, or `null` for the outlet segment. */
  blockName: string | null;
  /** Human-readable label shown in the breadcrumb. */
  displayName: string;
  /** Whether this segment represents the outlet boundary. */
  isOutlet: boolean;
  /** Name of the outlet containing this ancestry path. */
  outletName: string | null;
}

/** A `selectBlock` pre-change hook, fired with the outgoing/incoming keys. */
type BeforeChangeHook = (change: {
  /** Composite key that will become the primary selection. */
  nextKey: string | null;
  /** Composite key leaving the primary selection. */
  prevKey: string | null;
}) => void;

/** A `selectBlock` post-change hook, fired with the new primary key. */
type AfterChangeHook = (change: {
  /** Composite key of the new primary selection. */
  key: string | null;
}) => void;

/**
 * Owns the editor's block-selection concern: the primary selection, the
 * multi-selection set, and every getter the inspector / outline / toolbar
 * derive from "what is selected right now".
 *
 * `selectBlock` is the event seam between this concern and the rest of the
 * editor. Cross-concern effects that used to live inline (flushing pending
 * arg edits, committing an in-flight in-session text edit, revealing the
 * selection into view) are not known here — they are registered by the
 * orchestrator as before/after hooks so this service never reaches up into the
 * editor that drives it. It injects only the layout-signal beacon and the
 * layout-query service (both downward, dependency-free) — never the orchestrator.
 */
export default class WireframeSelectionService extends Service {
  /** Invalidates selection-derived layout state after structural changes. */
  @service declare wireframeLayoutSignal: WireframeLayoutSignalService;

  /** Resolves live entries, parents, outlets, and metadata. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;

  /** Gates document-level deselection to active editor sessions. */
  @service declare wireframeEditMode: WireframeEditModeService;

  /**
   * The PRIMARY (anchor) selected block key — the block whose form the
   * inspector shows when exactly one is selected, and the anchor for
   * shift-range selection.
   */
  @tracked selectedBlockKey: string | null = null;

  /**
   * Snapshot of the selected block populated by either the canvas chrome
   * (on click) or the outline panel (on row click). The shape is a loose
   * subset of
   * `{ key, name, id, args, containerArgs, conditions, outletArgs, outletName, metadata }`.
   * Some fields are only available from one entry
   * point — for example, `containerArgs` and `outletArgs` are only set when
   * the selection comes from a rendered block on the canvas.
   *
   * `args` here is the LIVE `entry.args` reference (a `trackedObject`); the
   * inspector reads through it so reads auto-track and edit-time mutations
   * are visible without us re-assigning `selectedBlockData`.
   */
  @tracked selectedBlockData: SelectedBlockData | null = null;

  /**
   * The full set of selected block keys. `selectedBlockKey` is the PRIMARY
   * (anchor) of this set — the block whose form the inspector shows when
   * exactly one is selected, and the anchor for shift-range selection.
   * Single-select keeps this at `{ primaryKey }`; the outline's modifier
   * gestures grow it. `isBlockSelected` reads it, so the canvas highlights
   * every member. A `trackedSet`, so `.has` / `.size` reads auto-track.
   * Held private so consumers can't mutate the live set; reads go through
   * `selectionCount` / `selectedKeysSnapshot` / `isBlockSelected`.
   */
  #selectedKeys = trackedSet<string>();

  /**
   * Callbacks fired at the start of `selectBlock`, BEFORE the selection
   * mutates — each receives `{ nextKey, prevKey }`. The orchestrator registers
   * its cross-concern pre-change effects here (flush pending args, commit
   * an in-flight in-session edit).
   */
  #beforeChange: BeforeChangeHook[] = [];

  /**
   * Callbacks fired at the end of `selectBlock`, AFTER the selection has
   * settled — each receives `{ key }` (the new primary key). The orchestrator
   * registers its cross-concern post-change effects here (reveal the
   * selection into view).
   */
  #afterChange: AfterChangeHook[] = [];

  /**
   * Tracks the mousedown target so the deselect handler can require BOTH the
   * down and up events to land outside the allowed scope. Without this, dragging
   * to select text inside an input (mousedown on input, mouseup outside its
   * bounds) would synthesise a `click` on the common ancestor — often `<body>` —
   * and trigger an accidental deselect.
   */
  #selectionMousedownTarget: EventTarget | null = null;

  /** Records the initial target of a possible outside-click deselection. */
  #onCanvasMouseDown = (event: MouseEvent): void => {
    this.#selectionMousedownTarget = event.target;
  };

  /**
   * Document-level mouseup handler that clears the selection when BOTH the
   * mousedown and mouseup landed outside the allowed scope. Installed once at
   * construction and gated on `wireframeEditMode.active`, so it's a no-op outside
   * an editor session. Guards on `isDestroyed`/`isDestroying` (plain instance
   * flags, no service lookup) so a leaked listener firing after teardown bails.
   */
  #onCanvasMouseUp = (event: MouseEvent): void => {
    const downTarget = this.#selectionMousedownTarget;
    this.#selectionMousedownTarget = null;
    if (this.isDestroyed || this.isDestroying) {
      return;
    }
    if (!this.wireframeEditMode.active || !this.selectedBlockKey) {
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
   * Creates the service and installs document-level selection listeners.
   *
   * @param owner - Ember owner used to initialize the service.
   */
  constructor(owner: Owner) {
    super(owner);
    // Document-level so a click anywhere off the editor surface can deselect.
    // The handler self-gates on the session, so it's harmless while inactive;
    // removed on teardown (willDestroy) so it never leaks past the owner.
    document.addEventListener("mousedown", this.#onCanvasMouseDown);
    document.addEventListener("mouseup", this.#onCanvasMouseUp);
  }

  /** Removes document-level selection listeners during teardown. */
  willDestroy(): void {
    super.willDestroy();
    document.removeEventListener("mousedown", this.#onCanvasMouseDown);
    document.removeEventListener("mouseup", this.#onCanvasMouseUp);
  }

  /**
   * Soft-failure metadata for the currently-selected block, or `null` if
   * the selection is healthy (or nothing is selected). Reads
   * `__failureType` / `__failureReason` written by the validator when
   * running in permissive mode — far more accurate than text-matching
   * the whole-outlet warning list against the selected block's name.
   */
  get selectedBlockFailure(): {
    /** Failure category recognised by the ghost-rendering path. */
    failureType: string;
    /** Human-readable validation failure. */
    failureReason: string;
  } | null {
    // Republishes bump `structuralVersion`; in-place stamp clears
    // propagate via the per-entry `trackedObject` wrap (the
    // `entry.__failureType` read below opens a per-key dep).
    void this.wireframeLayoutSignal.version;
    const key = this.selectedBlockKey;
    if (!key) {
      return null;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
    const entry = validatedEntry(located?.entry);
    if (!entry?.__failureType) {
      return null;
    }
    return {
      failureType: entry.__failureType,
      failureReason: entry.__failureReason ?? "",
    };
  }

  /**
   * Structured field-level errors for the selected block, keyed by arg
   * name. Each value is an array of `{ code, field, value?, expected? }`
   * details — permissive-mode validation accumulates every failure
   * inside an entry, so a field can carry multiple details in principle
   * (e.g. type + constraint).
   *
   * Details without a `field` are routed to `selectedBlockNonFieldErrors`
   * instead (the inspector lists them in the top pill, not under a
   * specific input).
   *
   * Drives FormKit's `addError` sync in the inspector — see
   * `inspector-form.gts`.
   */
  get selectedBlockFieldErrors(): Record<string, ValidationErrorDetails[]> {
    void this.wireframeLayoutSignal.version;
    const key = this.selectedBlockKey;
    if (!key) {
      return {};
    }
    const entry = validatedEntry(
      this.wireframeLayoutQuery.findEntryAndOutletSync(key)?.entry
    );
    const list = entry?.__failureDetails ?? [];
    const byField: Record<string, ValidationErrorDetails[]> = {};
    for (const d of list) {
      if (!d?.field) {
        continue;
      }
      (byField[d.field] ??= []).push(d);
    }
    return byField;
  }

  /**
   * Structured errors for the selected block that aren't tied to a
   * single field — constraint violations, missing children, unknown
   * block, duplicate IDs, etc. These render in the top-of-inspector
   * pill since they have no specific control to hang under.
   */
  get selectedBlockNonFieldErrors(): ValidationErrorDetails[] {
    void this.wireframeLayoutSignal.version;
    const key = this.selectedBlockKey;
    if (!key) {
      return [];
    }
    const entry = validatedEntry(
      this.wireframeLayoutQuery.findEntryAndOutletSync(key)?.entry
    );
    return (entry?.__failureDetails ?? []).filter((d) => !d?.field);
  }

  /**
   * Whether the selected block has any structured error (field-level
   * or not). Used by the inspector to decide whether to render the
   * compact errors pill.
   */
  get selectedBlockHasErrors(): boolean {
    return (
      Object.keys(this.selectedBlockFieldErrors).length > 0 ||
      this.selectedBlockNonFieldErrors.length > 0
    );
  }

  /**
   * Whether the selected block has a sibling above it. Drives the
   * `Move up` toolbar button's disabled state.
   */
  get canMoveSelectedUp(): boolean {
    return this.#selectionSiblingIndex() > 0;
  }

  /**
   * Whether the selected block has a sibling below it. Drives the
   * `Move down` toolbar button's disabled state.
   */
  get canMoveSelectedDown(): boolean {
    const idx = this.#selectionSiblingIndex();
    if (idx < 0) {
      return false;
    }
    const key = this.selectedBlockKey;
    if (!key) {
      return false;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return false;
    }
    const layout = this.wireframeLayoutQuery.readResolvedLayout(
      located.outletName
    );
    if (!layout) {
      return false;
    }
    const sibs = findEntrySiblings(layout, key);
    return sibs ? idx < sibs.siblings.length - 1 : false;
  }

  /**
   * Path of ancestor segments from the outlet root down to the
   * selected block. Used by the canvas-bottom breadcrumb. Each segment
   * carries `{key, blockName, displayName, isOutlet, outletName}`.
   * Outlet segment is first (`isOutlet: true`, `key: null`), nested
   * containers follow, selected block is last.
   */
  get selectedBlockAncestry(): BlockAncestrySegment[] {
    // Read structuralVersion so this re-evaluates after every mutation.

    void this.wireframeLayoutSignal.version;
    const key = this.selectedBlockKey;
    if (!key) {
      return [];
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return [];
    }
    const layout = this.wireframeLayoutQuery.readResolvedLayout(
      located.outletName
    );
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
        const meta = this.wireframeLayoutQuery.metadataFor(entry);
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
   * The selected entry's current serialised form, for the Raw JSON
   * inspector tab. Uses the same `serializeEntryForSave` that
   * `persistance` uses for the wire format — so what you see in the
   * Raw JSON tab matches what gets saved. Class references on
   * `entry.block` are normalised to their registered name strings,
   * and runtime-only fields (`__stableKey`, `__visible`, ...) are
   * dropped. Reads `structuralVersion` to refresh on every mutation.
   */
  get selectedBlockRawEntry(): Record<string, unknown> | null {
    void this.wireframeLayoutSignal.version;
    const key = this.selectedBlockKey;
    if (!key) {
      return null;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
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
   */
  get selectedBlockConditions(): object | object[] | null {
    // Force a tracked read so consumers re-render when structural
    // mutations re-publish.

    void this.wireframeLayoutSignal.version;
    const key = this.selectedBlockKey;
    if (!key) {
      return null;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return this.selectedBlockData?.conditions ?? null;
    }
    return located.entry.conditions ?? null;
  }

  /** Whether more than one block is currently selected. */
  get hasMultiSelection(): boolean {
    return this.#selectedKeys.size > 1;
  }

  /** The number of blocks currently selected. */
  get selectionCount(): number {
    return this.#selectedKeys.size;
  }

  /**
   * Tells whether a given block key is part of the current selection. Reads the
   * `selectedKeys` set (not just the primary), so under a multi-selection every
   * selected block's chrome / outline row highlights. Used only for highlight;
   * identity checks (e.g. "is this the block being edited in place") read
   * `selectedBlockKey` directly.
   *
   * @param key - The composite block key (`${name}:${__stableKey}`).
   */
  @action
  isBlockSelected(key: string | null): boolean {
    return key != null && this.#selectedKeys.has(key);
  }

  /**
   * A frozen, read-only copy of the selected keys. Consumers that need the
   * full set (e.g. for a multi-delete) read this instead of the live set so
   * they can't mutate the selection out from under this service.
   */
  selectedKeysSnapshot(): ReadonlyArray<string> {
    return Object.freeze([...this.#selectedKeys]);
  }

  /**
   * The lock declaration for the currently-selected part, or null when the
   * selection isn't a part. `true` means the whole part is locked (no in-place
   * arg overrides); a string array lists the specific arg names that can't be
   * overridden in place. Drives the inspector's disabling of locked fields.
   */
  partLockForSelection(): true | string[] | null {
    const context = this.wireframeLayoutQuery.resolvePartContext(
      this.selectedBlockKey ?? ""
    );
    if (!context) {
      return null;
    }
    return resolvePartDef(context.compositeEntry, context.idPath)?.lock ?? null;
  }

  /**
   * Selects a block as the PRIMARY (the inspector form + the multi-select
   * anchor). By default this also collapses the multi-selection to just this
   * block, so every existing caller stays single-select; the outline's
   * `toggleBlockSelection` / `setSelectionRange` pass `preserveMultiSelection`
   * to keep the surrounding set intact while moving the anchor.
   *
   * This is the event seam: it fires the registered before-change hooks
   * (with `{ nextKey, prevKey }`) before mutating, and the after-change hooks
   * (with `{ key }`) once the selection has settled.
   *
   * @param data - `{ key, ... }` (rest hydrated from the layout).
   * @param options - Controls whether selecting a new primary preserves the
   *   surrounding multi-selection.
   */
  selectBlock(
    data: SelectedBlockData | null,
    {
      preserveMultiSelection = false,
    }: {
      /** Whether existing multi-selection members should remain selected. */
      preserveMultiSelection?: boolean;
    } = {}
  ): void {
    const nextKey = data?.key ?? null;
    const prevKey = this.selectedBlockKey;

    // Fire the before-change hooks so cross-concern effects (flush pending
    // arg edits, commit an in-flight in-session text edit) run before the
    // selection mutates and we apply stale state to the new block.
    for (const fn of this.#beforeChange) {
      fn({ nextKey, prevKey });
    }

    this.selectedBlockKey = nextKey;

    // Unless a multi-select gesture is moving the anchor within an existing
    // set, the primary IS the whole selection.
    if (!preserveMultiSelection) {
      this.#selectedKeys.clear();
      if (data?.key != null) {
        this.#selectedKeys.add(data.key);
      }
    }

    if (!data) {
      this.selectedBlockData = null;
      for (const fn of this.#afterChange) {
        fn({ key: this.selectedBlockKey });
      }
      return;
    }

    // Programmatic callers (drag-and-drop auto-select, command-palette,
    // tests) may pass only `{ key }`. Resolve the rest from the live layout
    // so the inspector has the block's real metadata. Without this the args
    // would round-trip through `inferSchemaFromValues` and richly-typed
    // controls (image, icon, color) would degrade to the generic "any" code
    // editor.
    const hydrated = this.#hydrateSelectionByKey(data);

    // Bind `args` to the LIVE `entry.args` (a `trackedObject`) so consumers
    // that need a live read (canvas-side, undo restoration, etc.) see
    // current values. Walks `_getResolvedLayouts()`, which returns the
    // resolved entry per outlet — so when session-drafts are active, we
    // bind to the draft entry, not the underlying layer's.
    const liveData: SelectedBlockData = { ...hydrated };
    this.#bindLiveArgs(liveData);

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
    liveData.parentChildArgsSchema = this.#resolveParentChildArgsSchema(
      liveData.key
    );

    // Snapshot the parent's `args` so the inspector form can evaluate
    // `ui.conditional: { arg: "mode", equals: "grid" }` against the parent's
    // current mode. Bumping the structural version doesn't matter here
    // because changing the parent's mode strips this child's
    // `containerArgs.grid`, which forces a re-selection anyway.
    const parentEntry = liveData.key
      ? this.wireframeLayoutQuery.findEntryParent(liveData.key)
      : null;
    liveData.parentArgsSnapshot = parentEntry?.args
      ? { ...parentEntry.args }
      : {};

    // Whether the editor recognises this block type. Unregistered blocks have
    // no metadata, so the editor can't know their schema — the inspector shows
    // their values read-only rather than offering schema-less edits it can't
    // validate. Computed from the name (not the post-inference metadata, which
    // `#withInferredMetadata` populates with a synthetic schema below).
    liveData.isRegistered = liveData.name
      ? this.wireframeLayoutQuery.metadataForName(liveData.name) != null
      : true;

    // Augment metadata with an inferred args schema when the block didn't
    // declare one. We do this at selection time (not in the inspector form)
    // so the schema is a stable reference across the live keystroke session.
    // Without this, the inspector would re-compute its schema on every edit,
    // causing the FormKit `<form.Field>` components to remount — which would
    // tear down the input the user is typing in and trigger
    // "@name=... already in use" errors on rapid reselect.
    this.selectedBlockData = this.#withInferredMetadata(liveData);

    // Bring the freshly selected block into view (outline selection,
    // insert auto-select, undo/redo restore). No-ops when it's already
    // visible, so clicking a block on the canvas doesn't jolt the page.
    for (const fn of this.#afterChange) {
      fn({ key: this.selectedBlockKey });
    }
  }

  /**
   * Toggles a block in/out of the multi-selection (the outline's cmd/ctrl-click
   * gesture). Adding a block makes it the new primary; removing the primary
   * re-anchors to a remaining member (or clears the selection entirely).
   *
   * @param data - `{ key, ... }` for the toggled block.
   */
  toggleBlockSelection(data: SelectedBlockData): void {
    const key = data?.key;
    if (key == null) {
      return;
    }
    if (this.#selectedKeys.has(key)) {
      this.#selectedKeys.delete(key);
      if (this.selectedBlockKey === key) {
        // Re-anchor the primary to any remaining member so the inspector still
        // has a block to bind to (or clear when the set is now empty).
        const next = [...this.#selectedKeys][0] ?? null;
        this.selectBlock(next ? { key: next } : null, {
          preserveMultiSelection: true,
        });
      }
    } else {
      this.#selectedKeys.add(key);
      this.selectBlock(data, { preserveMultiSelection: true });
    }
  }

  /**
   * Replaces the multi-selection with `keys` and anchors the primary at
   * `anchorData` (the outline's shift-click range gesture).
   *
   * @param keys - The block keys to select.
   * @param anchorData - `{ key, ... }` for the anchor (clicked) block.
   */
  setSelectionRange(keys: string[], anchorData: SelectedBlockData): void {
    this.#selectedKeys.clear();
    for (const key of keys) {
      this.#selectedKeys.add(key);
    }
    this.selectBlock(anchorData, { preserveMultiSelection: true });
  }

  /**
   * Selects an outlet by selecting its implicit root `layout` block. The
   * selection then hydrates through the normal block path, so the inspector
   * surfaces the layout form (mode / gap / grid) for the outlet.
   *
   * @param outletName - Outlet whose implicit root should be selected.
   */
  selectOutlet(outletName: string): void {
    const key = this.wireframeLayoutQuery.outletRootKey(outletName);
    if (key) {
      this.selectBlock({ key });
    }
  }

  /**
   * Selects the parent of the currently-selected block: the enclosing container
   * block, or the outlet itself when the block sits directly in the outlet root.
   * A one-click step up the tree that mirrors the breadcrumb. No-op when nothing
   * is selected or the selection has no ancestor above it (the outlet root).
   */
  selectParent(): void {
    // Ancestry is [outlet, ...ancestors, selectedBlock]; the parent is the entry
    // immediately before the selected block. Fewer than two entries means the
    // selection is already the top of its outlet, so there's nowhere to go up.
    const ancestry = this.selectedBlockAncestry;
    if (ancestry.length < 2) {
      return;
    }
    const parent = ancestry[ancestry.length - 2];
    if (parent.isOutlet) {
      if (parent.outletName) {
        this.selectOutlet(parent.outletName);
      }
      return;
    }
    this.selectBlock({ key: parent.key, name: parent.blockName });
  }

  /**
   * Re-resolves the given block key against the current layout and rebinds
   * `selectedBlockKey` / `selectedBlockData`. If the key no longer exists,
   * clears the selection. Used after structural undo / redo to follow the
   * selection across layout snapshots.
   *
   * @param blockKey - Composite key to restore, or `null` to clear selection.
   */
  restoreSelection(blockKey: string | null): void {
    if (!blockKey) {
      this.selectBlock(null);
      return;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(blockKey);
    if (!located) {
      this.selectBlock(null);
      return;
    }
    const blockName = this.wireframeLayoutQuery.blockNameOf(located.entry);
    const metadata = blockName
      ? this.wireframeLayoutQuery.metadataForName(blockName)
      : null;
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
   * Clears the selection entirely WITHOUT firing the before/after hooks.
   * Used on editor `exit()` to tear the selection down — the hooks (flush
   * pending args, commit in-session edits, reveal-into-view) are
   * meaningless once the session is ending, and routing exit through
   * `selectBlock(null)` would fire them.
   */
  reset(): void {
    this.selectedBlockKey = null;
    this.selectedBlockData = null;
    this.#selectedKeys.clear();
  }

  /**
   * Whether `target` is inside an editor surface where a click must NOT
   * deselect — block chrome, the editor shell, the conditions floating panel,
   * or any Float-Kit portal (menus / modals / tooltips mount at body level,
   * outside the shell, but are conceptually part of the editor).
   *
   * @param target - Browser event target to test against editor surfaces.
   */
  isInsideAllowedScope(target: EventTarget | null): boolean {
    if (!(target instanceof Element)) {
      return false;
    }
    return Boolean(
      target.closest(".wireframe-block-chrome") ||
      target.closest(".wireframe-shell") ||
      target.closest(".wireframe-conditions-floating-panel") ||
      target.closest(".fk-d-menu") ||
      target.closest(".fk-d-menu-modal") ||
      target.closest(".fk-d-tooltip__content")
    );
  }

  /**
   * Registers a callback fired at the start of every `selectBlock`, before
   * the selection mutates. Receives `{ nextKey, prevKey }`.
   *
   * @param fn - Hook invoked before each primary selection change.
   */
  registerBeforeChange(fn: BeforeChangeHook): void {
    this.#beforeChange.push(fn);
  }

  /**
   * Registers a callback fired at the end of every `selectBlock`, after the
   * selection has settled. Receives `{ key }` (the new primary key).
   *
   * @param fn - Hook invoked after each primary selection change.
   */
  registerAfterChange(fn: AfterChangeHook): void {
    this.#afterChange.push(fn);
  }

  /**
   * The selected block's index among its siblings, or `-1` when nothing is
   * selected / locatable.
   */
  #selectionSiblingIndex(): number {
    // Read `structuralVersion` so this getter re-evaluates after every
    // structural mutation — keeps the toolbar's move buttons reactive.

    void this.wireframeLayoutSignal.version;
    const key = this.selectedBlockKey;
    if (!key) {
      return -1;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return -1;
    }
    const layout = this.wireframeLayoutQuery.readResolvedLayout(
      located.outletName
    );
    if (!layout) {
      return -1;
    }
    const sibs = findEntrySiblings(layout, key);
    return sibs?.index ?? -1;
  }

  /**
   * Fills in any selection fields that the caller didn't supply by resolving
   * the key against the current layout. A no-op when the caller already
   * passed full data (block-chrome's own click handler does, since it has
   * the entry in hand).
   *
   * @param data - Partial selection payload to hydrate from the live layout.
   */
  #hydrateSelectionByKey(data: SelectedBlockData): SelectedBlockData {
    if (!data?.key) {
      return data;
    }
    const needsHydration =
      data.name == null || data.args == null || data.metadata == null;
    if (!needsHydration) {
      return data;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(data.key);
    if (!located) {
      return data;
    }
    const blockName =
      data.name ?? this.wireframeLayoutQuery.blockNameOf(located.entry);
    const metadata =
      data.metadata ??
      (blockName
        ? this.wireframeLayoutQuery.metadataForName(blockName)
        : null) ??
      null;
    return {
      ...data,
      name: blockName,
      args: data.args ?? located.entry.args,
      metadata,
      outletName: data.outletName ?? located.outletName,
      conditions: data.conditions ?? located.entry.conditions ?? null,
    };
  }

  /**
   * Resolves `data.key` against the registered layouts and rebinds `data.args`
   * to the live entry's `args` (a `trackedObject`). The `findEntry` walk is
   * synchronous when validation has already completed (which it has by the
   * time the user can click a block). On the rare path where validation is
   * still pending we leave `data.args` as-is — the inspector renders against
   * the snapshot the caller passed in, and the next mutation flush picks up
   * the live binding.
   *
   * @param data - Selection payload whose arguments should be rebound.
   */
  #bindLiveArgs(data: SelectedBlockData): void {
    if (!data?.key) {
      return;
    }
    const layoutMap = this.wireframeLayoutQuery._resolvedLayouts();
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
   * @param key - Composite key of the entry whose parent schema is needed.
   */
  #resolveParentChildArgsSchema(
    key: string | null
  ): BlockMetadata["childArgs"] {
    if (!key) {
      return null;
    }
    const parent = this.wireframeLayoutQuery.findEntryParent(key);
    if (!parent) {
      return null;
    }
    const parentName = this.wireframeLayoutQuery.blockNameOf(parent);
    if (!parentName) {
      return null;
    }
    return (
      this.wireframeLayoutQuery.metadataForName(parentName)?.childArgs ?? null
    );
  }

  /**
   * Returns `data` unchanged when its metadata already declares an arg schema.
   * Otherwise (no declared schema but the block has args) augments the metadata
   * with a schema inferred from the current arg values via `inferSchemaFromValues`.
   * Done at selection time, not in the inspector, so the schema is a stable
   * reference across the keystroke session — keeping the inspector's form fields
   * from remounting on every edit.
   *
   * @param data - Selection payload whose metadata may need an inferred schema.
   */
  #withInferredMetadata(data: SelectedBlockData): SelectedBlockData {
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
}
