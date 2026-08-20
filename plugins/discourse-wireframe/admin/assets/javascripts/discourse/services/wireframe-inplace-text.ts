import { tracked } from "@glimmer/tracking";
import { type default as Owner, getOwner } from "@ember/owner";
import { next as nextRunloop } from "@ember/runloop";
import Service, { service } from "@ember/service";
import type { LayoutEntry } from "discourse/blocks/types";
import { resolvePartArgs } from "discourse/lib/blocks/-internals/composite";
import {
  clearValidatorStamps,
  entryKey,
  findEntrySiblings,
  insertEntryAt,
  removeEntry,
  replaceEntryContainerArgs,
  resolvePartDef,
  revalidateEntryStamps,
  sameValue,
  setPartOverride,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";
import {
  type RichTextDoc,
  toStorage,
} from "discourse/plugins/discourse-wireframe/discourse/lib/rich-text";
import type WireframeLayoutQueryService from "./wireframe-layout-query";
import type WireframeMutationEngineService from "./wireframe-mutation-engine";
import type WireframeSelectionService from "./wireframe-selection";

/** Screen coordinates used to place the initial editor selection. */
type SelectionCoordinates = {
  /** Horizontal viewport coordinate. */
  x: number;
  /** Vertical viewport coordinate. */
  y: number;
};

/** The selection applied when an inline editor next mounts. */
type InitialSelection =
  | "start"
  | "end"
  | "selectAll"
  | {
      /** Exact ProseMirror document position for the caret. */
      pos: number;
    }
  | {
      /** Screen coordinates from which ProseMirror resolves the caret. */
      coords: SelectionCoordinates;
    };

/** Options for opening an inline text session. */
type StartOptions = {
  /** Click coordinates used to place the caret. */
  coords?: SelectionCoordinates;
  /** An explicit initial selection. */
  initialSelection?: Exclude<
    InitialSelection,
    {
      /** Screen coordinates from which ProseMirror resolves the caret. */
      coords: SelectionCoordinates;
    }
  >;
};

/** Options for closing an inline-text session. */
type StopOptions = {
  /** Whether to record the session's final value instead of restoring it. */
  commit?: boolean;
};

/** Descriptor for the contextual field editor displayed by the block toolbar. */
export type InplaceFieldEditor = {
  /** Field-editor kind used to select the toolbar surface. */
  kind: string;
  /** Initial string value shown when the editor opens. */
  value: string;
  /**
   * Applies the current toolbar value.
   *
   * @param value - Current string entered in the toolbar.
   */
  apply?: (value: string) => void;
  /** Cancels the field-editing session. */
  cancel?: () => void;
  /** Removes the field value when the active editor supports removal. */
  remove?: () => void;
};

/** Controller commands exposed to the block toolbar during text editing. */
export type InplaceTextController = {
  /** Active inline-mark state, or `null` when mark actions are unavailable. */
  markState: {
    /** Whether the selection has the strong mark. */
    strong: boolean;
    /** Whether the selection has the emphasis mark. */
    em: boolean;
    /** Whether the selection has the link mark. */
    link: boolean;
  } | null;
  /**
   * Toggles an inline formatting mark on the current selection.
   *
   * @param markName - Mark to toggle on the current selection.
   */
  toggleMark(markName: "strong" | "em"): void;
  /** Opens the URL editor for the selected link range. */
  enterLinkMode(): void;
};

type LocatedEntry = {
  /** Resolved entry being edited. */
  entry: LayoutEntry;
  /** Outlet containing the resolved entry. */
  outletName: string;
};

type PartContext = {
  /** Composite key of the entry that owns the synthesized part. */
  compositeKey: string;
  /** Outlet containing the owning composite. */
  outletName: string;
  /** Override path of the synthesized part. */
  partPath: string;
};

type ContainerArgContext = {
  /** Key of the child whose placement argument is edited. */
  childKey: string;
  /** Outlet containing the child. */
  outletName: string;
  /** Container-argument namespace that owns the field. */
  namespace: string;
  /** Field within the container-argument namespace. */
  field: string;
};

/** Information about a sibling eligible for inline-text navigation. */
export type InplaceTextSibling = {
  /** Stable composite key of the sibling. */
  key: string;
  /** Sibling block reference. */
  block: LayoutEntry["block"] | null;
  /** Stored value of the active argument on the sibling. */
  value: unknown;
};

/**
 * Narrows a runtime value to a non-array object with unknown fields.
 *
 * @param value - Runtime value to inspect.
 * @returns Whether the value is a record-like object.
 */
function isUnknownRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

/**
 * Owns all state and operations for an inline-text edit session: which
 * `(blockKey, argName)` is being edited, the cached entry location, the
 * pre-edit value (for undo), the active controller, the commit callback,
 * the next-mount selection hint, plus the structural ops (split, merge)
 * and sibling-lookup helpers consumed by the keymap.
 *
 * A peer service in the editor's acyclic dependency graph. It injects only the
 * services that sit downstream of it — the mutation/undo engine (records the
 * session's edits), the read-only layout query layer (entry/outlet lookups),
 * and the selection concern (`restoreSelection` after a structural transition).
 * It never reaches back up into the orchestrator that drives it; the orchestrator keeps a
 * thin `inlineEdit` facade getter so its many consumers stay unchanged.
 *
 * It subscribes to the selection seam itself: switching selection to a
 * different block commits any in-flight session (see the constructor).
 */
export default class WireframeInplaceTextService extends Service {
  /** Mutation and undo service used to persist completed edit sessions. */
  @service declare wireframeMutationEngine: WireframeMutationEngineService;

  /** Read-only layout service used to resolve edit targets. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;

  /** Selection service used to close and restore editing sessions. */
  @service declare wireframeSelection: WireframeSelectionService;

  /**
   * Currently-editing block key. `null` when no session is active.
   * Tracked so the controller's `activeRendererEl` getter recomputes
   * when the session opens / closes / transitions to a new block.
   */
  @tracked blockKey: string | null = null;

  /**
   * Currently-editing arg name (e.g. `"text"`, `"title"`). `null` when
   * no session is active.
   */
  @tracked argName: string | null = null;

  /**
   * Cached entry + outlet for the editing session so `applyChange`
   * doesn't pay the `findEntryAndOutlet` cost on every keystroke.
   * Cleared by `stop`.
   *
   */
  #located: LocatedEntry | null = null;

  /**
   * Set instead of `#located` when the edited target is a synthesized
   * composite part (which has no persisted entry). Holds the owning
   * composite's key, outlet, and the override path, so the session commits
   * the final value as a per-part override rather than into a tracked
   * entry's args. `null` for an ordinary entry session.
   *
   */
  #partContext: PartContext | null = null;

  /**
   * Snapshot of the arg's pre-edit value, captured at `start` time.
   * Used to build the `prev` Map for the undo entry on commit, and to
   * restore the original value on revert. `null` when no edit is in
   * flight.
   *
   */
  #prevValue: unknown = null;

  /**
   * Block name (`wf:paragraph`, `wf:heading`, …) of the entry currently
   * being edited. Cached at session start so the PM keymap can branch
   * on block type per keystroke without re-walking the layout. Cleared
   * by `stop`.
   *
   */
  #blockName: LayoutEntry["block"] | null = null;

  /**
   * Selection hint for the next `mountEditor` call. `"selectAll"` (the
   * default) preserves the "start typing to replace" affordance for
   * fresh edit sessions. `"start"` / `"end"` are used by structural
   * transitions (Enter-split places the cursor at the start of the new
   * sibling). A `{ pos: number }` object places the cursor at an
   * exact document position — used by Backspace-merge so the cursor
   * lands at the join point (end of the original "before" content,
   * before the merged-in "after" content). A `{ coords: { x, y } }`
   * object is used by the click-to-edit gesture so the cursor lands
   * where the user clicked (`mountEditor` resolves the screen coords
   * via PM's `posAtCoords`). Consumed exactly once via
   * `consumeInitialSelectionHint`.
   *
   */
  #initialSelection: InitialSelection = "selectAll";

  /**
   * Callback the in-place text controller registers via `registerCommit`.
   * Invoked from `stop({ commit: true })` BEFORE the editing state is
   * cleared, so the controller can pull the final doc out of its
   * ProseMirror view and hand it back through `applyChange`. Decouples
   * the state object (which only tracks session state) from the
   * controller (which owns the editor DOM) without making this class
   * directly aware of PM.
   *
   */
  #commitFn: (() => void) | null = null;

  /**
   * Set instead of `#located` when the edited target is a *child's
   * containerArg* (e.g. a `tabs` strip label, stored at
   * `child.containerArgs.tab.label`) rather than the child's own arg. Holds
   * the child entry's key, its outlet, and the containerArgs namespace + field,
   * so the session commits the final value into that child's containerArgs
   * (a structural mutation via `replaceEntryContainerArgs`) rather than into a
   * tracked entry's args. `null` for an ordinary entry or part session. This
   * is the third in-place text target type, alongside the entry-arg and
   * composite-part (`#partContext`) types.
   *
   * Tracked so the controller's `activeRendererEl` getter (which reads it via
   * `containerArgContext`) recomputes when the session opens / moves / closes —
   * without this the cached element stuck on the first target and commits bled
   * the value into the wrong tab / block.
   *
   */
  @tracked _containerArgContext: ContainerArgContext | null = null;

  /**
   * Reference to the active `InplaceTextController` instance — the
   * component that owns the ProseMirror view and exposes
   * `toggleMark` / `enterLinkMode` / `applyLink` / `removeLink` /
   * `cancelLink` to consumers.
   *
   * Set in the controller's constructor via `registerController` and
   * cleared on `willDestroy`. The block-toolbar reads it through the
   * `controller` getter to render the inline-format buttons.
   *
   * Tracked so consumers (block-toolbar) re-render when the editor
   * becomes available or goes away.
   *
   */
  @tracked _controller: InplaceTextController | null = null;

  /**
   * Contextual toolbar slot — when non-null, the block toolbar transitions
   * into a field-editing mode driven by this state instead of showing default
   * block actions. Generic shape: `{ kind, value, apply, cancel, remove? }`.
   * PM's link-mark editing AND block-arg URL editing both populate this with
   * `kind: "url"`; future kinds (e.g. `"color"`, `"image"`) plug into the same
   * slot without re-architecting. Exactly one slot is active at a time — a new
   * source setting it implicitly closes the previous session.
   *
   * Held here (rather than a separate concern) because it's in-place text state:
   * the PM link-mark controller drives it. Read-only via `fieldEditor`; written
   * via `setFieldEditor`.
   *
   */
  @tracked _fieldEditor: InplaceFieldEditor | null = null;

  /**
   * Creates the service and registers its selection-change session boundary.
   *
   * @param owner - Ember owner used to initialize the service.
   */
  constructor(owner: Owner) {
    super(owner);
    // Own our reaction to selection changes: switching selection to a different
    // block commits any in-flight in-place text session. Re-selecting the same
    // block leaves it alone — that's the second-click-to-edit gesture.
    //
    // Registered once at instantiation and permanent for the app lifetime (the
    // seam has no unregister). It fires on every selection change regardless of
    // editor active-state, which is safe: the guard no-ops when no session is
    // active (`blockKey` is null). The composition root looks this service up
    // at boot so the subscription exists before the first selection change.
    this.wireframeSelection.registerBeforeChange(({ nextKey }) => {
      if (this.blockKey && this.blockKey !== nextKey) {
        this.stop({ commit: true });
      }
    });
  }

  /**
   * The active contextual toolbar field-editor slot, or `null`. See
   * `_fieldEditor`.
   */
  get fieldEditor(): InplaceFieldEditor | null {
    return this._fieldEditor;
  }

  /** Whether an inline-text session is active. */
  get isActive(): boolean {
    return this.blockKey != null;
  }

  /**
   * Block name of the entry currently being edited, or `null` when no
   * session is active. Read by the PM keymap to branch behaviour per
   * block type (e.g. Enter splits a paragraph block but commits-and-
   * exits in a heading).
   */
  get blockName(): LayoutEntry["block"] | null {
    return this.#blockName;
  }

  /**
   * The active containerArg target (`{ childKey, namespace, field }`) when this
   * is a containerArg session, else `null`. The controller reads it to resolve
   * the renderer span via a dedicated `[data-wf-container-arg-key]` selector
   * instead of `[data-wf-block-key]` (the editable span lives in the parent's
   * render, not the child's chrome).
   */
  get containerArgContext(): Omit<ContainerArgContext, "outletName"> | null {
    if (!this._containerArgContext) {
      return null;
    }
    const { childKey, namespace, field } = this._containerArgContext;
    return { childKey, namespace, field };
  }

  /**
   * Live value of the arg being edited. Falls through to the schema
   * default when the entry has no value for this arg — matches the
   * lookup `createBlockArgsWithReactiveGetters` uses to compute the
   * block's displayed `@arg` value (`decorator.js:462-464`).
   */
  get argValue(): unknown {
    // Part session: the pre-edit value captured at `start` is the part's
    // effective arg; ProseMirror owns the value for the rest of the session.
    if (this.#partContext) {
      return this.#prevValue;
    }
    // ContainerArg session: same — the snapshot seeds ProseMirror, which then
    // owns the value until commit.
    if (this._containerArgContext) {
      return this.#prevValue;
    }
    if (!this.#located || !this.argName) {
      return undefined;
    }
    const { entry } = this.#located;
    const live = entry.args?.[this.argName];
    if (live !== undefined) {
      return live;
    }
    const schema = this.wireframeLayoutQuery.metadataFor(entry)?.args;
    return schema?.[this.argName]?.default;
  }

  /**
   * Public read-side of the controller registration. The block-toolbar
   * consults this to decide whether to show the inline-format buttons
   * and to call their commands.
   */
  get controller(): InplaceTextController | null {
    return this._controller;
  }

  /**
   * Sets (or clears, with `null`) the contextual toolbar field-editor slot.
   * Replaces any previously active descriptor (the slot holds exactly one).
   *
   * @param descriptor - Field editor to expose, or `null` to clear the slot.
   */
  setFieldEditor(descriptor: InplaceFieldEditor | null): void {
    this._fieldEditor = descriptor;
  }

  /**
   * Begins an inline-text edit session for `(blockKey, argName)`. Captures
   * the arg's current value as the pre-edit snapshot so a single
   * `{ kind: "args" }` undo entry can be pushed at the end of the session.
   * Implicitly commits + ends any other session in flight.
   *
   * The canvas chrome calls this from its click handler when the user
   * clicks a `[data-wf-rich-text-arg]` region of a selected block. Per-
   * keystroke mutations after this point go through `applyChange`,
   * which bypasses the undo stack — PM's internal undo handles in-session
   * granularity until `stop` flushes a single entry on commit.
   *
   * @param blockKey - Composite key of the block or synthesized part to edit.
   * @param argName - Name of the rich-text argument to edit.
   * @param options - Initial caret-placement options for the session.
   * @returns `true` if the session opened.
   */
  async start(
    blockKey: string,
    argName: string,
    options: StartOptions = {}
  ): Promise<boolean> {
    if (!blockKey || !argName) {
      return false;
    }
    if (this.blockKey === blockKey && this.argName === argName) {
      return true;
    }
    if (this.blockKey) {
      this.stop({ commit: true });
    }
    const located =
      await this.wireframeLayoutQuery.findEntryAndOutlet(blockKey);
    if (located) {
      this.#located = located;
      this.#partContext = null;
      this._containerArgContext = null;
      this.#prevValue = located.entry.args?.[argName];
      this.#blockName = located.entry.block ?? null;
    } else {
      // No persisted entry: this is a synthesized composite part. Resolve the
      // owning composite + override path so the session commits as a per-part
      // override. The pre-edit value is the part's effective arg (its
      // code-default merged with any current override).
      const partContext =
        this.wireframeLayoutQuery.resolvePartContext(blockKey);
      const partDef = partContext
        ? resolvePartDef(partContext.compositeEntry, partContext.idPath)
        : null;
      if (!partContext || !partDef) {
        return false;
      }
      // TODO(devxp-typescript-pending): remove this cast once core's
      // `LayoutEntry.overrides` uses the path-to-argument-map shape already
      // required by `resolvePartArgs`.
      const override = partContext.compositeEntry.overrides?.[
        partContext.partPath
      ] as Record<string, unknown> | undefined;
      this.#located = null;
      this._containerArgContext = null;
      this.#partContext = {
        compositeKey: partContext.compositeKey,
        outletName: partContext.outletName,
        partPath: partContext.partPath,
      };
      this.#prevValue = resolvePartArgs(partDef, override)[argName];
      this.#blockName = this.wireframeLayoutQuery.blockNameOf({
        block: partDef.block,
      });
    }
    if (options.coords) {
      this.#initialSelection = { coords: options.coords };
    } else if (options.initialSelection !== undefined) {
      this.#initialSelection = options.initialSelection;
    }
    this.blockKey = blockKey;
    this.argName = argName;
    return true;
  }

  /**
   * Begins an inline-text edit session for a CHILD's containerArg
   * (`child.containerArgs[namespace][field]`) — e.g. a `tabs` strip label.
   * Captures the current containerArg value as the pre-edit snapshot so the
   * session commits as a single structural mutation. Implicitly commits + ends
   * any other session in flight.
   *
   * Called from the canvas chrome when the user clicks a
   * `[data-wf-container-arg-key]` region — the parent renders the editable span
   * for a child whose placement it owns. Per-keystroke mutations go through
   * `applyChange` → `#applyContainerArgChange` (committed on `stop`).
   *
   * @param childKey - Child entry whose container argument is edited.
   * @param namespace - Container-argument namespace, such as `"tab"`.
   * @param field - Field within the namespace, such as `"label"`.
   * @param options - Optional click coordinates used to place the caret.
   * @returns `true` if the session opened.
   */
  async startContainerArg(
    childKey: string,
    namespace: string,
    field: string,
    options: Pick<StartOptions, "coords"> = {}
  ): Promise<boolean> {
    if (!childKey || !namespace || !field) {
      return false;
    }
    const ctx = this._containerArgContext;
    if (
      ctx &&
      ctx.childKey === childKey &&
      ctx.namespace === namespace &&
      ctx.field === field
    ) {
      return true;
    }
    if (this.blockKey) {
      this.stop({ commit: true });
    }
    const located =
      await this.wireframeLayoutQuery.findEntryAndOutlet(childKey);
    if (!located) {
      return false;
    }
    this.#located = null;
    this.#partContext = null;
    this._containerArgContext = {
      childKey,
      outletName: located.outletName,
      namespace,
      field,
    };
    const namespaceArgs = located.entry.containerArgs?.[namespace];
    this.#prevValue = isUnknownRecord(namespaceArgs)
      ? namespaceArgs[field]
      : undefined;
    this.#blockName = located.entry.block ?? null;
    if (options.coords) {
      this.#initialSelection = { coords: options.coords };
    }
    this.blockKey = childKey;
    this.argName = field;
    return true;
  }

  /**
   * Ends the inline-text edit session. On `commit: true`, pushes a
   * single `{ kind: "args" }` undo entry capturing the pre-edit value
   * as `prev` and the current value as `next` — but only when the
   * value actually changed; a no-op edit doesn't pollute the undo
   * stack. On `commit: false`, restores the pre-edit value without
   * pushing an entry (used by Escape-to-cancel paths).
   *
   * The keystroke stream went straight through `applyChange` (no
   * per-keystroke undo push). On `commit: true` a single
   * `{ kind: "args" }` entry is recorded capturing the whole session.
   *
   * @param options - Whether to commit or cancel the active session.
   */
  stop({ commit = true }: StopOptions = {}): void {
    // Part session: on commit, the registered callback pulls ProseMirror's
    // final doc and routes it through `applyChange`, which writes a per-part
    // override (a structural commit that records its own undo). On cancel,
    // nothing was written during the session, so PM teardown simply discards
    // the edit — there's no entry value to restore.
    if (this.#partContext) {
      if (commit && this.#commitFn) {
        this.#commitFn();
      }
      this.#located = null;
      this.#partContext = null;
      this.#prevValue = null;
      this.#blockName = null;
      this.#initialSelection = "selectAll";
      this.blockKey = null;
      this.argName = null;
      return;
    }

    // ContainerArg session: on commit, the registered callback pulls the final
    // doc and routes it through `applyChange` → `#applyContainerArgChange`,
    // which writes the child's containerArg (a structural commit that records
    // its own undo). On cancel, nothing was written, so PM teardown discards
    // the edit — there's no entry value to restore.
    if (this._containerArgContext) {
      if (commit && this.#commitFn) {
        this.#commitFn();
      }
      this.#located = null;
      this._containerArgContext = null;
      this.#prevValue = null;
      this.#blockName = null;
      this.#initialSelection = "selectAll";
      this.blockKey = null;
      this.argName = null;
      return;
    }

    const located = this.#located;
    const argName = this.argName;
    if (!located || !argName) {
      this.blockKey = null;
      this.argName = null;
      return;
    }

    // Pull the final value out of ProseMirror BEFORE clearing state, so
    // the controller's commit callback (which calls `applyChange`)
    // writes to a session whose location is still resolved.
    if (commit && this.#commitFn) {
      this.#commitFn();
    }

    const { entry } = located;
    const prevValue = this.#prevValue;
    const nextValue = entry.args?.[argName];

    if (commit) {
      if (!sameValue(prevValue, nextValue)) {
        this.wireframeMutationEngine.pushUndoEntry({
          kind: "args",
          entry,
          prev: new Map([[argName, prevValue]]),
          next: new Map([[argName, nextValue]]),
        });
        this.wireframeMutationEngine.clearRedoStack();
      }
    } else {
      this.wireframeMutationEngine.writeArgs(
        entry,
        new Map([[argName, prevValue]])
      );
    }

    this.#located = null;
    this.#prevValue = null;
    this.#blockName = null;
    this.#initialSelection = "selectAll";
    this.blockKey = null;
    this.argName = null;
  }

  /**
   * Writes the final value of an inline-text edit session into
   * `entry.args[argName]`. Invoked exactly once per session, via the
   * commit callback registered by the controller (see `registerCommit`)
   * — `stop({ commit: true })` calls the callback, which reads
   * ProseMirror's final doc and forwards it here. We deliberately do
   * NOT write per keystroke: ProseMirror is the visible source of truth
   * during the session, and per-keystroke writes exposed the system to
   * spurious "PM emptied its doc during teardown" transactions that
   * clobbered `args.text` with `""`.
   *
   * Keeps the existing dirty-tracking honest: flags the entry's outlet as
   * arg-edited so persistence knows what to save, and captures the
   * initial-snapshot so `resetAll` rolls back the right pre-edit state.
   *
   * @param value - The new value (string for plain edits, doc-JSON
   *   for marked edits) produced by `toStorage(doc.toJSON())`.
   */
  applyChange(value: unknown): void {
    if (this.#partContext) {
      this.#applyPartChange(value);
      return;
    }
    if (this._containerArgContext) {
      this.#applyContainerArgChange(value);
      return;
    }
    const located = this.#located;
    const argName = this.argName;
    if (!located || !argName) {
      return;
    }
    const { entry, outletName } = located;
    this.wireframeMutationEngine.markOutletArgEdited(outletName);
    const prevMap = new Map([[argName, entry.args?.[argName]]]);
    this.wireframeMutationEngine.captureInitialSnapshot(entry, prevMap);
    // Empty edits (`""`, null, undefined) DELETE the key rather than
    // write an explicit empty string. The block decorator's reactive
    // getter (`createBlockArgsWithReactiveGetters` at
    // `decorator.js:462-464`) only falls back to the schema `default`
    // when the key is missing; writing `""` would lock out the default
    // and leave the canvas visually empty even though the renderer's
    // placeholder is set.
    // Write directly against `entry.args`: a nullish `args` must throw here
    // rather than be silently initialized, matching the pre-existing contract.
    if (value == null || value === "") {
      delete entry.args![argName];
    } else {
      entry.args![argName] = value;
    }
    // Re-validate against the new value so the outline / inspector reflect
    // the block's current validity instead of clearing the error until the
    // next republish (e.g. emptying a required inline field re-flags it).
    revalidateEntryStamps(entry, { owner: getOwner(this) });
  }

  /**
   * Returns the pending initial-selection hint for the next mount and
   * resets it to the default (`"selectAll"`). One-shot — `mountEditor`
   * calls this exactly once when setting up the editor's initial
   * selection.
   */
  consumeInitialSelectionHint(): InitialSelection {
    const hint = this.#initialSelection;
    this.#initialSelection = "selectAll";
    return hint;
  }

  /**
   * Splits the current `wf:paragraph` edit session into two sibling
   * paragraph entries at the cursor. The current entry keeps the
   * "before" doc; a freshly-minted sibling holds the "after" doc and
   * becomes the new active edit target with the cursor at position 0.
   *
   * The PM keymap calls this with the cursor-split doc-JSON pair. The
   * whole mutation rides one `recordStructural` block so Cmd+Z reverts
   * the split atomically — there's no intermediate `applyChange`
   * write, since we hand-write both docs directly in the recording
   * window.
   *
   * No-ops (returns `false`) when there's no active session, the active
   * arg isn't `text`, or the editing entry isn't a `wf:paragraph` block.
   *
   * @param args - Stored documents before and after the split position.
   * @returns Whether the paragraph was split.
   */
  splitAt({
    beforeDoc,
    afterDoc,
  }: {
    /** Document content retained by the current paragraph. */
    beforeDoc: RichTextDoc;
    /** Document content assigned to the new following paragraph. */
    afterDoc: RichTextDoc;
  }): boolean {
    const blockKey = this.blockKey;
    const argName = this.argName;
    if (!blockKey || argName !== "text") {
      return false;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(blockKey);
    if (!located || located.entry.block !== "paragraph") {
      return false;
    }
    const { entry: currentEntry, outletName } = located;
    const align = currentEntry.args?.align;
    const afterValue = toStorage(afterDoc);
    const afterArgs: Record<string, unknown> = {};
    if (afterValue !== "" && afterValue != null) {
      afterArgs.text = afterValue;
    }
    if (align !== undefined) {
      afterArgs.align = align;
    }
    const newEntry: LayoutEntry = { block: "paragraph", args: afterArgs };
    let newKey: string | null = null;

    const result = this.wireframeMutationEngine.recordStructural(
      [outletName],
      () => {
        // Write the "before" doc back into the current entry. Direct
        // mutation on the live entry is safe here — we're inside the
        // structural-recording window, so the pre-state was already
        // captured. Match `applyChange`'s contract of deleting the key
        // on empty so the schema default surfaces.
        const beforeValue = toStorage(beforeDoc);
        if (beforeValue === "" || beforeValue == null) {
          delete currentEntry.args!.text;
        } else {
          currentEntry.args!.text = beforeValue;
        }
        clearValidatorStamps(currentEntry);
        this.wireframeMutationEngine.markOutletStructurallyEdited(outletName);

        const layout = this.wireframeMutationEngine.ensureDraft(outletName);
        if (!layout) {
          return false;
        }
        const insertion = insertEntryAt(layout, blockKey, newEntry, "after");
        if (!insertion.changed) {
          return false;
        }
        this.wireframeMutationEngine.publishStructuralChange(
          outletName,
          insertion.layout
        );

        // `publishStructuralChange` ran `assignStableKeys`, so the new
        // entry now has its composite key.
        newKey = entryKey(newEntry);
        return !!newKey;
      }
    );
    if (!result || !newKey) {
      return false;
    }

    this.#transitionTo(newKey, { initialSelection: "start" });
    return true;
  }

  /**
   * Returns the previous sibling of the currently-editing entry within
   * the same outlet — `{ key, block, value }` — or `null` if no session
   * is active, the current entry is the first sibling, or the lookup
   * fails. `value` is the sibling's stored value for the active arg
   * (string or doc-JSON); callers decide what to do with it.
   *
   * Filtering by block type is intentionally left to the caller — the
   * Backspace-merge handler bails when `block !== "paragraph"`; the
   * arrow-walk handler does the same. A future cross-block-type handler
   * might accept other blocks.
   *
   * @returns The previous sibling details, or `null` when none exists.
   */
  prevSiblingInfo(): InplaceTextSibling | null {
    return this.#getSiblingInfo(-1);
  }

  /**
   * Returns the next sibling of the currently-editing entry, or `null`
   * if it's the last sibling. Mirror of `prevSiblingInfo`; used by
   * cross-block arrow nav to decide whether ArrowRight at end /
   * ArrowDown on the bottom line should walk to the next sibling.
   *
   * @returns The next sibling details, or `null` when none exists.
   */
  nextSiblingInfo(): InplaceTextSibling | null {
    return this.#getSiblingInfo(1);
  }

  /**
   * Merges the current `wf:paragraph` edit session into its previous
   * sibling. The keymap rebuilds the prev's PM doc (via `toDoc(prevValue)`
   * + `Node.fromJSON`), concats the current PM doc onto its end, and
   * passes the merged doc-JSON here along with `joinPos` — the absolute
   * doc position where the boundary between the original prev content
   * and the merged-in current content sits. That position becomes the
   * cursor's new home via the `{ pos }` initial-selection hint.
   *
   * The whole mutation rides one `recordStructural` block so Cmd+Z
   * restores both paragraphs atomically. The current entry is removed;
   * the prev entry absorbs the merged value.
   *
   * No-ops (returns `false`) when there's no active session, the active
   * arg isn't `text`, the editing entry isn't a `wf:paragraph` block,
   * or no prev sibling exists. Cross-block-type merges (paragraph into
   * heading, etc.) are explicitly out of scope here — the keymap
   * filters those out before calling.
   *
   * @param args - Merged document and the cursor position at its former boundary.
   * @returns Whether the paragraphs were merged.
   */
  mergeWithPrev({
    mergedDoc,
    joinPos,
  }: {
    /** Document produced by joining the previous and current paragraphs. */
    mergedDoc: RichTextDoc;
    /** Cursor position at the former boundary between the paragraphs. */
    joinPos: number;
  }): boolean {
    const blockKey = this.blockKey;
    const argName = this.argName;
    if (!blockKey || argName !== "text") {
      return false;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(blockKey);
    if (!located || located.entry.block !== "paragraph") {
      return false;
    }
    const { outletName } = located;
    const layout = this.wireframeLayoutQuery.readResolvedLayout(outletName);
    if (!layout) {
      return false;
    }
    const sibs = findEntrySiblings(layout, blockKey);
    if (!sibs || sibs.index <= 0) {
      return false;
    }
    const prevEntry = sibs.siblings[sibs.index - 1];
    const prevKey = entryKey(prevEntry);
    if (!prevKey) {
      return false;
    }

    const result = this.wireframeMutationEngine.recordStructural(
      [outletName],
      () => {
        // Write the merged value into the prev entry. Match `applyChange`'s
        // contract of deleting the key on empty so the schema default
        // surfaces.
        const livePrev = this.wireframeLayoutQuery.findEntryByKey(prevKey);
        if (!livePrev) {
          return false;
        }
        const mergedValue = toStorage(mergedDoc);
        if (mergedValue === "" || mergedValue == null) {
          delete livePrev.args!.text;
        } else {
          livePrev.args!.text = mergedValue;
        }
        clearValidatorStamps(livePrev);
        this.wireframeMutationEngine.markOutletStructurallyEdited(outletName);

        const draft = this.wireframeMutationEngine.ensureDraft(outletName);
        if (!draft) {
          return false;
        }
        const removal = removeEntry(draft, blockKey);
        if (!removal.changed) {
          return false;
        }
        this.wireframeMutationEngine.publishStructuralChange(
          outletName,
          removal.layout
        );
        return true;
      }
    );
    if (!result) {
      return false;
    }

    this.#transitionTo(prevKey, { initialSelection: { pos: joinPos } });
    return true;
  }

  /**
   * The in-place text controller calls this in `mountEditor` to register a
   * commit callback (and again with `null` in `unmountEditor` to clear).
   * The callback is invoked by `stop({ commit: true })` just before the
   * editing state is cleared, giving the controller a chance to pull
   * the current ProseMirror doc and write it through `applyChange`.
   *
   * @param fn - Commit callback, or `null` when the controller unmounts.
   */
  registerCommit(fn: (() => void) | null): void {
    this.#commitFn = fn;
  }

  /**
   * Called by `InplaceTextController` from its constructor to expose the
   * controller (and its `toggleMark` / `enterLinkMode` / `applyLink` /
   * `removeLink` / `cancelLink` methods) to the block-toolbar, which
   * renders the inline-format buttons in the same chrome as the
   * move / duplicate / delete buttons.
   *
   * @param controller - Active controller exposing inline-format commands.
   */
  registerController(controller: InplaceTextController): void {
    this._controller = controller;
  }

  /**
   * Inverse of `registerController`. Called from the controller's
   * `willDestroy`. Guarded by reference equality so a stray unregister
   * from a previous controller can't clobber a newer one.
   *
   * @param controller - Controller that is leaving the editing surface.
   */
  unregisterController(controller: InplaceTextController): void {
    if (this._controller === controller) {
      this._controller = null;
    }
  }

  /**
   * Commits the final value of a part edit session into the owning
   * composite's per-part override map. A structural commit (the synthesis
   * reads `entry.overrides` at render time), so it routes through
   * `recordStructural` for undo/redo and re-publishes the draft layer. An
   * empty value removes the override key, reverting that arg to the part's
   * code default — matching `applyChange`'s delete-on-empty contract.
   *
   * @param value - Final value produced by the inline editor.
   */
  #applyPartChange(value: unknown): void {
    const partContext = this.#partContext;
    const argName = this.argName;
    if (!partContext || !argName) {
      return;
    }
    const { compositeKey, outletName, partPath } = partContext;
    this.wireframeMutationEngine.recordStructural([outletName], () => {
      const layout = this.wireframeLayoutQuery.readResolvedLayout(outletName);
      if (!layout) {
        return false;
      }
      const result = setPartOverride(
        layout,
        compositeKey,
        partPath,
        (current) => {
          const merged = { ...current };
          if (value == null || value === "") {
            delete merged[argName];
          } else {
            merged[argName] = value;
          }
          return merged;
        }
      );
      if (!result.changed) {
        return false;
      }
      this.wireframeMutationEngine.markOutletStructurallyEdited(outletName);
      this.wireframeMutationEngine.publishStructuralChange(
        outletName,
        result.layout
      );
      return true;
    });
  }

  /**
   * Commits the final value of a containerArg edit session into the child
   * entry's `containerArgs[namespace][field]`. A structural commit (the parent
   * reads `child.containerArgs` at render time), so it routes through
   * `recordStructural` for undo/redo and re-publishes the draft layer. An empty
   * value removes the field, matching `applyChange`'s delete-on-empty contract.
   *
   * @param value - Final value produced by the inline editor.
   */
  #applyContainerArgChange(value: unknown): void {
    const context = this._containerArgContext;
    if (!context) {
      return;
    }
    const { childKey, outletName, namespace, field } = context;
    // Normalise an empty value to `undefined` (the field is deleted, not stored
    // as `""`) so the no-op gate below treats empty→empty as unchanged.
    const isEmpty = value == null || value === "";
    const nextValue = isEmpty ? undefined : value;
    // `replaceEntryContainerArgs` always reports a change on a key match, so
    // gate the commit ourselves: an unchanged value must not push an undo entry
    // or republish — mirroring the entry-arg undo gate in `stop`.
    const prevValue = this.#prevValue == null ? undefined : this.#prevValue;
    if (sameValue(prevValue, nextValue)) {
      return;
    }
    this.wireframeMutationEngine.recordStructural([outletName], () => {
      const layout = this.wireframeLayoutQuery.readResolvedLayout(outletName);
      if (!layout) {
        return false;
      }
      const result = replaceEntryContainerArgs(
        layout,
        childKey,
        namespace,
        (current) => {
          const merged = { ...current };
          if (value == null || value === "") {
            delete merged[field];
          } else {
            merged[field] = value;
          }
          return merged;
        }
      );
      if (!result.changed) {
        return false;
      }
      this.wireframeMutationEngine.markOutletStructurallyEdited(outletName);
      this.wireframeMutationEngine.publishStructuralChange(
        outletName,
        result.layout
      );
      return true;
    });
  }

  /**
   * Resolves an adjacent sibling of the active entry.
   *
   * @param direction - Relative sibling offset to inspect.
   * @returns Adjacent sibling details, or `null` when unavailable.
   */
  #getSiblingInfo(direction: -1 | 1): InplaceTextSibling | null {
    const blockKey = this.blockKey;
    if (!blockKey) {
      return null;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(blockKey);
    if (!located) {
      return null;
    }
    const layout = this.wireframeLayoutQuery.readResolvedLayout(
      located.outletName
    );
    if (!layout) {
      return null;
    }
    const sibs = findEntrySiblings(layout, blockKey);
    if (!sibs) {
      return null;
    }
    const target = sibs.siblings[sibs.index + direction];
    if (!target) {
      return null;
    }
    // TODO(devxp-typescript-pending): the historical contract returns the
    // sibling unconditionally; a resolved sibling entry always carries a stable
    // key and an active session always has an arg name, but the types can't
    // prove either, so assert at this boundary.
    return {
      key: entryKey(target) as string,
      block: target.block ?? null,
      value: target.args?.[this.argName as string],
    };
  }

  /**
   * Moves the active edit session to a different block once Glimmer has
   * rendered the target block's chrome into the DOM. Used by structural
   * ops (`splitAt`, `mergeWithPrev`) that publish a new layout and
   * immediately want PM to remount on a different entry.
   *
   * Flipping `blockKey` synchronously would race the controller's
   * `activeRendererEl` lookup (it queries `[data-wf-block-key=...]`
   * which doesn't exist until the canvas mounts the new block-chrome).
   * Defer past `afterRender` via `nextRunloop`, then rAF-poll for the
   * element — the canvas's chrome mount can land later than the
   * standard render phase. Bails after a fixed attempt count so a
   * genuinely-missing element doesn't spin forever.
   *
   * Once the element is found (or the poll gives up), all session-
   * scoped state is reset to the new entry and `restoreSelection`
   * runs so the chrome's `--selected` reveal rule unhides the empty
   * placeholder for the destination block.
   *
   * @param key - Composite key of the entry becoming active.
   * @param options - Initial selection to apply after the transition.
   */
  #transitionTo(
    key: string,
    {
      initialSelection,
    }: {
      /** Selection applied after the destination editor mounts. */
      initialSelection: InitialSelection;
    }
  ): void {
    const transitionWhenReady = (attempts = 0): void => {
      const found = document.querySelector(
        `[data-wf-block-key="${CSS.escape(key)}"]`
      );
      if (found || attempts > 10) {
        this.#located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
        const argName = this.argName;
        this.#prevValue = argName
          ? this.#located?.entry?.args?.[argName]
          : undefined;
        this.#blockName = this.#located?.entry?.block ?? null;
        this.#initialSelection = initialSelection;
        this.blockKey = key;
        this.wireframeSelection.restoreSelection(key);
        return;
      }
      requestAnimationFrame(() => transitionWhenReady(attempts + 1));
    };
    nextRunloop(this, transitionWhenReady);
  }
}
