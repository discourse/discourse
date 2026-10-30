import { DEBUG } from "@glimmer/env";
import { cached } from "@glimmer/tracking";
import { untrack } from "@glimmer/validator";
import { isDestroying, registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import { bind } from "discourse/lib/decorators";
import { makeArray } from "discourse/lib/helpers";
import SelectCustomizations, {
  type SelectPresentationOptions,
  type SelectResolvedContext,
  type SelectResolvedOptions,
  type SelectRowPresentation,
} from "discourse/ui-kit/select/-internals/engine/customizations";
import ListComposer from "discourse/ui-kit/select/-internals/engine/list-composer";
import SelectOptionsView from "discourse/ui-kit/select/-internals/engine/select-options";
import {
  filterLocal,
  localItems,
  LocalSource,
  PagedSource,
  type SelectSource,
  SelectState,
} from "discourse/ui-kit/select/-internals/engine/select-sources";
import SelectionActions from "discourse/ui-kit/select/-internals/engine/selection-actions";
import ValueResolver from "discourse/ui-kit/select/-internals/engine/value-resolver";
import {
  applyLegacySelectKitContent,
  applyLegacySelectKitOnChange,
} from "discourse/ui-kit/select/-internals/modify-select-kit-bridge";
import { i18n } from "discourse-i18n";
import SelectionUpdates, {
  type SelectionOrigin,
} from "./-internals/engine/selection-updates.ts";

/**
 * A single item's value id. Items carry arbitrary, dynamically-keyed fields, so the
 * value read out of an item is `unknown` rather than a fixed scalar type.
 */
export type SelectItemId = unknown;

/**
 * The controlled value: a single id (or `null`) for single-select, or a (frozen) id
 * array for multi-select.
 */
export type SelectValue = SelectItemId | readonly SelectItemId[] | null;

/**
 * A selectable item. Domain fields are addressed dynamically through `valueField` /
 * `labelField`, so they are exposed via the index signature; the few structural fields
 * the engine understands directly are declared explicitly.
 */
export interface SelectItem {
  /**
   * Action-item hook: when present, activating the item runs this instead of selecting
   * it, and receives the select's {@link SelectControl}. A row injected through the
   * `modifySelectKit` compat bridge gets the legacy select-kit facade instead.
   */
  onSelect?: (control: SelectControl, item: SelectItem) => void;

  /** Kept at the top of the list and visible while it scrolls. Structural rows ignore this. */
  sticky?: boolean;

  /** When true, the item cannot be activated (guards both pointer and keyboard). */
  disabled?: boolean;

  /** Visible secondary text, exposed as the option's description rather than its name. */
  description?: string;

  /** Marks the synthetic create-on-the-fly item. */
  __create?: boolean;

  /** Marks a synthetic fallback for a held value that could not be resolved. */
  __unresolved?: boolean;

  /**
   * Marks a text group-header row (engine-injected when `groupHeader` returns text). A structural
   * row: it is never selectable, navigable, or counted in the option set. Carries its `label`.
   */
  __header?: boolean;

  /** Marks a text group-footer row, the footer counterpart of `__header`. */
  __footer?: boolean;

  /**
   * Marks the engine's copy of an action row that `groupHeader` returned. It stays a navigable
   * option; the marker routes it to the `<:groupHeader>` block.
   */
  __groupHeader?: boolean;

  /** Marks the engine's copy of an action row that `groupFooter` returned. */
  __groupFooter?: boolean;

  /**
   * Marks an engine-injected splitter before a group that has no header of either kind, except
   * at the head of the list; consumers never set it.
   */
  __divider?: boolean;

  /**
   * Marks the synthetic single-select "none" row (engine-injected from `noneLabel`). Selectable
   * and navigable like any option, but its value field is `null`, so selecting it clears the
   * selection.
   */
  __none?: boolean;

  /** Arbitrary domain fields, addressed dynamically by `valueField` / `labelField`. */
  [key: string]: unknown;
}

/**
 * The normalized render descriptor for one row, computed as the final step before render
 * (see {@link SelectEngine#buildItems}). It carries a stable `key` (never an index; models
 * need no `id`), the `value` (id) for selection, the untouched raw `item` yielded to
 * `:item` / `:selection`, and the row `flags` so components read state from one place.
 */
export interface SelectDescriptor {
  /**
   * Stable `{{#each}}` key: the normalized value for a record, or an engine key (prefixed
   * `__ds:`) for a row the engine builds, such as a group row, which follows its group rather
   * than its position. A record key that already starts with the prefix is escaped.
   */
  key: string;
  /** The row's id (raw, from `valueField`). */
  value: SelectItemId;
  /** The raw model, passed through untouched to consumer blocks. */
  item: SelectItem;
  /** Row state, centralized so the template and option component don't re-derive it. */
  flags: {
    /** Whether this row's value is part of the current selection. */
    selected: boolean;
    /** Whether this option stays at the top while the list scrolls. */
    sticky: boolean;
    /** Whether the row cannot be activated (guards both pointer and keyboard). */
    disabled: boolean;
    /** Whether the consumer marked the item disabled. */
    reasonDisabled: boolean;
    /** Whether the selection cap prevents adding this option. */
    capDisabled: boolean;
    /** A group header, text or action. */
    groupHeader: boolean;
    /** A group footer, text or action. */
    groupFooter: boolean;
    /**
     * A text header or text footer: structural, so it is skipped by selection, navigation, and
     * the option-position math (no `posInSet`/`setSize`). Rendered outside the option set. An
     * action header or footer is an option instead.
     */
    textBoundary: boolean;
    /** A divider row: structural like a header, but presentational and label-less. */
    divider: boolean;
    /** An action row: it runs its `onSelect` and never becomes a value. */
    action: boolean;
    /** Marks the synthetic create-on-the-fly row. */
    __create: boolean;
    /** True for an unresolved held value; false on list rows. */
    __unresolved: boolean;
    /** True for the injected single-select "none" row (a selectable row that clears the value). */
    __none: boolean;
  };
  /**
   * Zero-based position among all list options, including disabled rows. Structural rows and
   * trigger/chip descriptors leave it undefined.
   */
  logicalIndex?: number;
  /**
   * Zero-based ordinal of the row's group, dense over every group shown, headed or not. Every
   * row the grouping emits carries it except splitters; ungrouped rows leave it undefined.
   */
  groupOrdinal?: number;
  /** Which text boundaries the row's group has, so its rows can be described by them. */
  groupText?: { header: boolean; footer: boolean };
  /**
   * 1-based position in the whole result set, independent of how many rows are mounted.
   * Stamped by {@link SelectEngine#buildItems} only; the trigger/chip path leaves it
   * undefined.
   */
  posInSet?: number;
  /**
   * Size of the whole result set when a source reports or derives one, and otherwise the count
   * of rows loaded so far — a source mid-paging under `hasMore: true` with no `total`, or one
   * stopped by the barren-page brake. Never `-1`: the ARIA sentinel for an unknown size has no
   * consistent implementation, so an honest count of the reachable rows is preferred and the
   * "more exists" half is announced instead.
   */
  setSize?: number;
}

export function selectItemLabel(
  item: SelectItem | null | undefined,
  labelField = "name"
): string {
  return String(item?.[labelField] ?? "");
}

/** Options threaded into a source (`load` / `resolveValue`) call. */
export interface SelectLoadOptions {
  /** Resolved core and recipe values, supplied by the select engine. */
  options?: SelectResolvedOptions;
  /** Shallow snapshot of `@loadContext`, shared by every page of this query. */
  context?: Readonly<Record<string, unknown>>;
  /** Maximum page length requested from a paginated source. */
  limit?: number;
  /** Raw source offset for a paginated request. */
  offset?: number;
  /** Opaque cursor returned by the previous successful page; cleared for a new query. */
  cursor?: unknown;
  /**
   * The 1-based page number for a source that pages by number: 1 on a query's first request,
   * then one more after each settled page, barren pages included. A failed or abandoned
   * request is asked again under the same number. Set for `load` only.
   */
  page?: number;
  /** Cancels a superseded request. */
  signal?: AbortSignal;
}

/** A page from a server-backed source, with optional pagination metadata. */
export interface SelectLoadResponse {
  /** The page returned for the requested offset. */
  items: SelectItem[];
  /** Opaque continuation value passed unchanged to the next request as `opts.cursor`. */
  cursor?: unknown;
  /**
   * The source's true result count when available. This is a fact about the whole set and
   * is carried forward across responses for the current query. It also licenses another
   * fetch on its own: a total above the rows returned so far means more remain.
   */
  total?: number;
  /**
   * Whether another page exists. This applies only to this response and is not carried
   * forward. `true` promises the next requested offset will yield rows not already returned.
   *
   * **Omitting it means `false`.** A source that paginates must say so; one that stays silent
   * is taken at its word that the rows it returned are the whole set, and they are reported
   * as such through `aria-setsize`. Passing `false` explicitly is equivalent and allowed, so
   * a cursor API can forward its own flag unmodified.
   */
  hasMore?: boolean;
}

/** Shapes accepted from a select item source. */
export type SelectLoadResult = SelectItem[] | SelectLoadResponse;

/** A frozen read-only view of the engine state passed to a `specialItems` builder. */
export interface SelectSnapshot {
  filter: string;
  value: SelectValue;
  hasValue: boolean;
}

/**
 * Read-only handles the `modifySelectKit` compat bridge needs to build its facade,
 * supplied by the component. Not part of the consumer-facing API.
 */
export interface SelectLegacyContext {
  owner?: Owner;
  getElement?: () => Element | null;
  isDestroyed?: () => boolean;
}

/** Options for {@link SelectControl#reload}. */
export interface SelectReloadOptions {
  /**
   * Shows the loading state at once instead of after the usual delay, for a reload that changes
   * what the list shows (a different source), where the current rows are already wrong.
   */
  immediate?: boolean;
}

/**
 * The live handle for action rows and content, options, load, and change customizations.
 * The object stays frozen for the select's life. Its methods are for event time,
 * never for render-time callbacks, and do nothing once the select is destroyed.
 */
export interface SelectControl {
  /** The held value. */
  readonly value: SelectValue;
  /** The current filter text. */
  readonly filter: string;
  /** Whether asynchronous update work is in flight. */
  readonly pending: boolean;
  /** Closes the overlay. */
  close(): void;
  /** Selects an item, exactly as picking its row would. */
  select(item: SelectItem): void;
  /** Adds eligible items in one change; single-select chooses the first new item. */
  selectMany(items: readonly SelectItem[]): void;
  /** Removes an item if held; single-select clears its held item. */
  deselect(item: SelectItem): void;
  /** Clears a nonempty selection. */
  clear(): void;
  /** Starts a new query without superseding a pending update. */
  reload(options?: SelectReloadOptions): void;
  /** Runs event-time work with write authority until it ends or is superseded. */
  update(
    work: (scope: SelectUpdateScope) => void | Promise<void>
  ): Promise<void>;
}

/** The write authority and cancellation signal of one update, without overlay or update controls. */
export interface SelectUpdateScope {
  /**
   * Cancels work with an `AbortError` when superseded or destroyed.
   * Own writes, reloads, and a pure `current` read do not abort it.
   */
  readonly signal: AbortSignal;
  /** Whether this update still owns the live value. A pure read. */
  readonly current: boolean;
  /** Selects an item while current and unlocked. */
  select(item: SelectItem): void;
  /** Adds eligible items in one change; single-select chooses the first new item. */
  selectMany(items: readonly SelectItem[]): void;
  /** Removes a held item while current and unlocked. */
  deselect(item: SelectItem): void;
  /** Clears a nonempty selection while current and unlocked. */
  clear(): void;
}

/**
 * Builds a group's header or footer from its key and surviving rows: text, an action row (an
 * item with `onSelect`), or nullish for none.
 */
export type SelectGroupBoundaryBuilder = (
  key: SelectItemId,
  rows: readonly SelectItem[],
  options: SelectResolvedOptions
) => string | SelectItem | null | undefined;

/**
 * Constructor options for a {@link SelectEngine}.
 *
 * Function-valued options are invoked with an unspecified receiver — read the provided
 * arguments, never `this`. Where a callback acts on the select, it is handed a
 * {@link SelectControl} (see {@link SelectItem#onSelect}).
 *
 * The `get*` reader options are the live counterparts of the plain option beside each:
 * they reflect runtime changes to the underlying `@arg`, while the plain static option
 * is a construction-time snapshot for direct,
 * non-reactive consumers. A component wires these to its live args; the engine re-applies
 * each default on read.
 */
export interface SelectEngineOptions {
  /** Multi-select when true (drives value shape, chips, and close-on-select). */
  multiple?: boolean;

  /** Omits held options when composing the list. Defaults to false. */
  hideSelected?: boolean;

  /** Live reader for {@link hideSelected}. */
  getHideSelected?: () => boolean | undefined;

  /**
   * `() => value` — reads the controlled value live (single: an id or `null`; multi: an
   * id array). Must read tracked state for changing values; a fixed value is also supported.
   * In-place array edits require a tracked collection. Untracked changes are unsupported.
   * Defaults to always-`null`.
   */
  getValue?: () => SelectValue;

  /** Live reader for whether scope writes are locked. Defaults to false. */
  getLocked?: () => boolean;

  /** Live reader for {@link multiple}. */
  getMultiple?: () => boolean | undefined;

  /** Live reader for {@link minChars}. */
  getMinChars?: () => number | undefined;

  /** Live reader for {@link maxLoaded}. */
  getMaxLoaded?: () => number | undefined;

  /** Live reader for {@link maximum}. */
  getMaximum?: () => number | false | undefined;

  /** Live reader for {@link minimum}. */
  getMinimum?: () => number | undefined;

  /** Live reader for {@link noneLabel}. */
  getNoneLabel?: () => string | undefined;

  /** Live raw presentation args, read before any items, resolved selection, or lock state. */
  getOptions?: () => Readonly<SelectPresentationOptions>;

  /** Recipe option keys and base values; keys are fixed at construction. Requires `kind`. */
  kindOptions?: Record<string, unknown>;

  /** Live base values for {@link kindOptions}; the initial keys declare the schema. */
  getKindOptions?: () => Record<string, unknown> | undefined;

  /** Live reader for {@link valueItems}. */
  getValueItems?: () => SelectItem | SelectItem[] | undefined;

  /** Live reader for {@link allowCreate}. */
  getAllowCreate?: () => SelectEngineOptions["allowCreate"];

  /** The recipe or family name, fixed at construction. */
  kind?: string;

  /** Temporary names for the deprecated modifySelectKit bridge and legacy CSS only. */
  legacyKinds?: string[];

  /** The call-site name, fixed at construction. */
  identifier?: string;

  /**
   * Live reader for the recipe's data, passed to customizations as `context.kindContext`.
   * This carries what the recipe knows, such as its scope.
   */
  getKindContext?: () => object | undefined;

  /**
   * Live reader for the call site's data, passed to customizations as `context.instanceContext`, such
   * as the topic being edited.
   */
  getInstanceContext?: () => object | undefined;

  /**
   * A static array (or `(options) => array`) of items — the client-only source. Provide this
   * or `load`, not both.
   */
  items?:
    | SelectItem[]
    | ((options: SelectResolvedOptions) => SelectItem[] | null | undefined);

  /**
   * `(filter, { signal, offset, limit, page, cursor, context, options }) => items | { items, total?, hasMore?, cursor? }`,
   * synchronously or as a promise. Pagination starts without a limit so the source defines
   * its page size.
   *
   * A response that declares neither `total` nor `hasMore` — including a bare array — is
   * taken as the complete set, so a paginating source **must** declare one of them or only
   * its first page is ever shown.
   *
   * Called after the current render, never inside it, so it may write tracked state. State it
   * reads is not tracked: a change to it never re-asks the source. Supply `loadContext`
   * for reactive inputs, or call `reload()` explicitly.
   */
  load?: (
    filter: string,
    opts: SelectLoadOptions
  ) => SelectLoadResult | Promise<SelectLoadResult>;

  /**
   * The loader inputs whose own keys and values determine whether the list reloads. An array
   * entry compares by its elements, one level deep; every other entry compares by identity.
   */
  loadContext?: Readonly<Record<string, unknown>>;

  /** Live reader for {@link loadContext}. */
  getLoadContext?: () => SelectEngineOptions["loadContext"];

  /** Called when a list reload invalidates result announcements. */
  onReloadList?: () => void;

  /**
   * Client-filter field name or `(item, term, options) => boolean`. Defaults to a substring
   * match on `labelField`.
   */
  filterBy?:
    | string
    | ((
        item: SelectItem,
        term: string,
        options: SelectResolvedOptions
      ) => boolean);

  /**
   * Minimum filter length before the list searches. `0` (default) searches on any input.
   * A query shorter than this — including the empty query — is "below threshold": the list
   * issues no source call and the component shows a keep-typing hint. See
   * {@link SelectEngine#belowMinChars}.
   */
  minChars?: number;

  /** Optional server row ceiling with a filter-to-narrow hint. Uncapped by default. */
  maxLoaded?: number;

  /**
   * Hard cap on a multi-select's selection count. Ignored when not `multiple`; `false` means
   * no cap. Numbers below `1` and NaN also mean no cap but warn once per engine in development.
   * At the cap every add is refused — pointer, keyboard, create-on-the-fly and
   * the compat bridge all reach the same guard — and every unselected ordinary option reports
   * itself disabled. See {@link SelectEngine#atMaximum}.
   *
   * The cap is measured against the value read at activation time, so it holds for a consumer
   * that applies the emitted value synchronously and by replacement (the contract this
   * controlled component already assumes). One that applies it asynchronously, or merges
   * additively, can still land over the cap: two activations racing a pending update both read
   * the pre-update value. The engine deliberately keeps no selection state of its own, so it
   * cannot reserve a pending slot. Count validation at submit time belongs to the consuming
   * form, not here.
   *
   * It never trims an existing value: a caller that arrives already over the cap keeps every
   * held id and can still remove them, because silently dropping data on mount is worse than
   * showing an over-cap selection.
   */
  maximum?: number | false;

  /**
   * Advisory minimum for a multi-select: it drives {@link SelectEngine#belowMinimum} and the
   * limit messaging only. It never blocks removal — deselecting and clearing always succeed,
   * down to an empty selection — so enforcement stays with the consuming form.
   */
  minimum?: number;

  /**
   * Single-select only: the label for a first-class "none" row prepended to the list. Selecting it
   * clears the value to `null`. Shown only while the filter is empty (so a non-matching search can
   * still reach the empty state); omitted entirely on multi-select, where the "none" concept is the
   * placeholder rather than a row.
   */
  noneLabel?: string;

  /** Field holding an item's value. Defaults to `"id"`. */
  valueField?: string;

  /** Field holding an item's label. Defaults to `"name"`. */
  labelField?: string;

  /**
   * Already-resolved item(s) for the ids in `value`, so the trigger displays them without a
   * fetch. It selects nothing on its own: every entry is looked up BY `value`, so supplying
   * this without a matching `value` shows the placeholder.
   *
   * Unlike a resolver, it is read reactively, so items may arrive after mount — a consumer
   * loading them itself can hand them over when they land and every selection surface
   * refreshes. A resolver cannot do that: its outcome is cached, including the failure, and
   * only `reload()` retries it.
   */
  valueItems?: SelectItem | SelectItem[];

  /**
   * `(value, { signal, options }) => item | Promise<item>`, used to resolve a value id to its
   * display item when it isn't already known.
   */
  resolveValue?: (
    value: SelectItemId,
    opts: SelectLoadOptions
  ) => SelectItem | Promise<SelectItem | undefined> | undefined;

  /**
   * Batch counterpart to `resolveValue` for multi-select:
   * `(values, { signal, options }) => items | Promise<items>`. The engine calls it once for the uncached
   * ids (cached / seeded ids are skipped) so N chips never mean N requests. Omitted or errored
   * ids become fallbacks.
   */
  resolveValues?: (
    values: SelectItemId[],
    opts: SelectLoadOptions
  ) => SelectItem[] | Promise<SelectItem[]>;

  /**
   * Enables the create-on-the-fly item; a function `(filter, items, options) => boolean` gates it
   * dynamically against the displayed query and its loaded rows.
   */
  allowCreate?:
    | boolean
    | ((
        filter: string,
        items: SelectItem[],
        options: SelectResolvedOptions
      ) => boolean);

  /**
   * `(filter, options) => item` producing the synthetic "create" item. Name it by its value
   * text; the engine marks the row as create and supplies the "Create" wording.
   */
  createItem?: (filter: string, options: SelectResolvedOptions) => SelectItem;

  /**
   * `(value, options) => item` producing the fallback for a held id that could not be resolved,
   * so a recipe can name it (e.g. `Topic #123`) instead of showing the bare id. The
   * engine marks the result `__unresolved` regardless of what the builder returns.
   * Defaults to the id itself on `labelField`.
   */
  createUnresolvedItem?: (
    value: SelectItemId,
    options: SelectResolvedOptions
  ) => SelectItem;

  /**
   * `(snapshot, options) => item[]` prepended to the list (e.g. a "none"/"uncategorized" item).
   */
  specialItems?: (
    snapshot: SelectSnapshot,
    options: SelectResolvedOptions
  ) => SelectItem[];

  /**
   * Groups the filtered options by a field name or `(item, options) => key`. A group without a
   * header of either kind gets an unlabeled divider, except at the head of the list or when
   * `groupDividers` is false. A client source merges every row of a key into one group; a
   * source that pages groups consecutive rows, so a later page only extends the last group or
   * adds new ones, and a key that comes back starts another group.
   */
  groupBy?:
    | string
    | ((item: SelectItem, options: SelectResolvedOptions) => SelectItemId);

  /**
   * Whether a group without a header gets a divider before it. Defaults to true; false groups
   * rows only to place their headers and footers, with no boundary drawn between groups. Read
   * once, like `groupBy`.
   */
  groupDividers?: boolean;

  /**
   * `(key, rows, options) => text | actionRow | null` builds a group's header. Text renders a
   * presentational header; an item with `onSelect` renders a navigable action row. A group
   * with no header of either kind gets an unlabeled divider instead (see `groupDividers`).
   * `rows` are the group's surviving rows, frozen; for the last group of a source
   * that pages, the rows loaded so far. Runs during render, so it must be pure, and it must
   * return nullish for an `undefined` key.
   */
  groupHeader?: SelectGroupBoundaryBuilder;

  /**
   * Builds a group's footer, with the same signature and results as `groupHeader`. For a
   * source that pages, the last group's footer waits until the source can no longer grow, so
   * rows already shown never move.
   */
  groupFooter?: SelectGroupBoundaryBuilder;

  /** Whether choosing an item closes the overlay. Defaults to `!multiple`. */
  closeOnSelect?: boolean;

  /**
   * `(nextValue, item|items, change) => void`, where `nextValue` is the id(s) and the second arg
   * is the resolved item(s), each matching the arity. The parent applies `nextValue` to
   * `@value`. The third argument carries origin, clear metadata, and resolved options.
   */
  onChange?: (
    nextValue: SelectValue,
    item: SelectItem | SelectItem[] | null,
    change: {
      /** The programmatic intent behind this change, absent for hand picks. */
      origin?: SelectionOrigin;
      /** Distinguishes a whole-selection clear from removing an item. */
      reason?: "clear";
      /** The options snapshot shared with the change middleware. */
      options: SelectResolvedOptions;
    }
  ) => void;

  /** Called when a programmatic pick confirms an already held item. */
  onReconfirm?: (item: SelectItem, origin: SelectionOrigin) => void;

  /** Called when a batch adds nothing because every eligible item was held or over the limit. */
  onBulkUnchanged?: (skipped: { held: number; limit: number }) => void;

  /** Called when asynchronous work becomes pending; the reader checks its authority. */
  onUpdateStart?: (isCurrent: () => boolean) => void;

  /**
   * Called by the engine to ask the overlay to close (wired by the component to the menu
   * instance).
   */
  requestClose?: () => void;

  /**
   * Handles for the `modifySelectKit` compat bridge, supplied by the component:
   * `{ owner, getElement, isDestroyed }`. Only needed when the select carries
   * a kind that legacy extensions may target.
   */
  legacy?: SelectLegacyContext | null;
}

/** The {@link SelectControl} an engine hands out, frozen and guarded against a destroyed select. */
class EngineControl implements SelectControl {
  #engine: SelectEngine;

  constructor(engine: SelectEngine) {
    this.#engine = engine;
    Object.freeze(this);
  }

  get value(): SelectValue {
    return this.#engine.value;
  }

  get filter(): string {
    return this.#engine.filter;
  }

  get pending(): boolean {
    return this.#engine.pending;
  }

  clear(): void {
    if (!isDestroying(this.#engine)) {
      this.#engine.clear({ programmatic: true });
    }
  }

  close(): void {
    if (!isDestroying(this.#engine)) {
      this.#engine.requestClose();
    }
  }

  deselect(item: SelectItem): void {
    if (!isDestroying(this.#engine)) {
      this.#engine.deselect(item, { programmatic: true });
    }
  }

  /** Starts a new query while the select is alive, preserving update authority. */
  reload(options?: SelectReloadOptions): void {
    if (!isDestroying(this.#engine)) {
      this.#engine.reload(options);
    }
  }

  select(item: SelectItem): void {
    if (!isDestroying(this.#engine)) {
      this.#engine.select(item, { programmatic: true });
    }
  }

  /** Adds a batch while the select is alive. */
  selectMany(items: readonly SelectItem[]): void {
    if (!isDestroying(this.#engine)) {
      this.#engine.selectMany(items, { programmatic: true });
    }
  }

  update(
    work: (scope: SelectUpdateScope) => void | Promise<void>
  ): Promise<void> {
    return this.#engine.update(work);
  }
}

/**
 * Headless, DOM-free controller for the ui-kit select family. It is **controlled**:
 * the parent owns the value (`@value`), which the engine reads live via a `getValue`
 * thunk and never stores. The engine owns only internal UI state — the filter, a
 * reload nonce, and a resolved-item cache — plus the selection *logic*: it derives
 * `isSelected`/display from the value, builds the rendered item list (content
 * customizations + create-on-the-fly + special items), resolves a value id to its
 * display item(s), and emits `onChange(nextValue, item|items)` for the parent to apply.
 *
 * It renders nothing: `DSelect` and its internal parts drive the DOM from this public
 * API. Consumers and tests never touch the engine directly — they use `DSelect`'s args
 * and observe `onChange`/DOM. Internal parts receive the engine but only call its
 * public methods and read its frozen getters; there is no public mutable field.
 */
export default class SelectEngine {
  #state = new SelectState();

  // Fires the `@items`+`@load` misconfiguration warning at most once per engine.
  #dualSourceWarned = false;

  #options: SelectOptionsView;
  #legacyKinds: readonly string[];
  #valueResolver: ValueResolver;
  #selectionActions: SelectionActions;
  #selectionUpdates: SelectionUpdates;
  #listComposer: ListComposer;
  #source!: SelectSource;
  #control: SelectControl;
  #getLoadContext: () => SelectEngineOptions["loadContext"];
  #onReloadList?: () => void;
  #requestContextQuery?: string;
  #requestLoadContext?: Readonly<Record<string, unknown>>;

  /**
   * Copies of the snapshot's array entries, so a later check can tell an equal array derived
   * afresh from a changed one, even when the caller mutated the snapshotted array in place.
   */
  #requestContextArrays = new Map<PropertyKey, readonly unknown[]>();

  /** The query an immediate reload started, compared with the live {@link queryKey}. */
  #immediateQueryKey: string | null = null;

  /** Sealed declarations collected once, before source validation. */
  #customizations: SelectCustomizations;

  /**
   * @param opts - The engine's configuration; every field is documented on
   *   {@link SelectEngineOptions}.
   */
  constructor(opts: SelectEngineOptions = {}) {
    this.#legacyKinds = Object.freeze([...(opts.legacyKinds ?? [])]);
    this.#getLoadContext = opts.getLoadContext ?? (() => opts.loadContext);
    this.#onReloadList = opts.onReloadList;
    this.#options = new SelectOptionsView(opts);
    this.#control = new EngineControl(this);
    this.#valueResolver = new ValueResolver({
      options: this.#options,
      knownRows: () => this.#source.knownRows(),
    });
    this.#selectionActions = new SelectionActions({
      options: this.#options,
      runChange: (defaultStep, context) =>
        this.#customizations.runChange(defaultStep, context),
      onIntent: (origin) => this.#selectionUpdates.handleIntent(origin),
      beforeEmit: (origin, value) =>
        this.#selectionUpdates.prepareEmit(origin, value),
      runActionItem: (item) => item.onSelect!(this.#control, item),
      getExtensionContext: () => ({
        ...this.#extensionContext(),
        control: this.#control,
      }),
      cacheResolved: (item) => this.#valueResolver.cacheResolved(item),
      resolveOneSync: (value) => this.#valueResolver.resolveOneSync(value),
      applyLegacyOnChange: (value, payload) =>
        applyLegacySelectKitOnChange(this, value, payload),
    });
    this.#selectionUpdates = new SelectionUpdates({
      engine: this,
      options: this.#options,
      state: this.#state,
      actions: this.#selectionActions,
    });
    registerDestructor(this, () => this.#selectionUpdates.supersede());
    this.#listComposer = new ListComposer({
      options: this.#options,
      applyContent: (items, context) =>
        this.#customizations.applyContent(items, context),
      getFilter: () => this.#state.filter,
      getValue: () => this.value,
      getHasValue: () => this.hasValue,
      isSelected: (item) => this.isSelected(item),
      getAtMaximum: () => this.atMaximum,
      getTotal: () => this.total,
      noteVisible: (visible, input) => this.#source.noteVisible(visible, input),
      canGrow: () => this.#source.mayGrow(),
      applyLegacyContent: (items) => applyLegacySelectKitContent(this, items),
      getContentContext: () => ({
        ...this.#extensionContext(),
        control: this.#control,
      }),
    });
    this.#source = this.#options.load
      ? new PagedSource({
          resolveLoad: (filter) => this.#resolveLoad(filter),
          state: this.#state,
          getMaxLoaded: () => this.#options.maxLoaded,
          keyOf: (item) =>
            this.#options.valueKey(this.#options.itemValue(item)),
        })
      : new LocalSource({
          filtered: () => this.filteredItems,
          all: () => localItems(this.#options),
        });
    this.#customizations = new SelectCustomizations(
      {
        kind: this.kind,
        identifier: this.identifier,
      },
      this.#options.kindOptions
    );
    this.#options.attachResolvedOptions(() => this.resolvedOptions);
    // Catch a both-sources misconfiguration up front (before any menu opens); the same
    // check also runs per load for a live `items` source that turns non-empty later.
    this.#assertSingleSource();
    // Checked here, during render, because the resolver's own check runs inside an async
    // data source that turns a throw into a rejection instead of failing the render.
    if (DEBUG && this.hasValue) {
      this.#valueResolver.assertCanResolve(this.value);
    }
  }

  /** The current filter term. */
  get filter(): string {
    return this.#state.filter;
  }

  /** Identifies a query across its pages, including explicit reloads of the same filter. */
  get queryKey(): string {
    return JSON.stringify([this.#state.nonce, this.#state.filter]);
  }

  /**
   * Whether the current query came from `reload({ immediate: true })`, so its loading state
   * shows without the usual delay. Any later query, typed or reloaded, clears it.
   */
  get immediateLoadFeedback(): boolean {
    return (
      this.#immediateQueryKey !== null &&
      this.#immediateQueryKey === this.queryKey
    );
  }

  /** The most recently started query's loader inputs, distinct from retained displayed rows. */
  get requestLoadContext(): Readonly<Record<string, unknown>> | undefined {
    return this.#requestLoadContext;
  }

  /**
   * The controlled value, normalized and memoized from the consumer's tracked state.
   *
   * @returns A frozen id array (multiple) or a single id / `null`.
   */
  get value(): SelectValue {
    return this.#selectionActions.value;
  }

  /** One reactive options pass shared by the engine, presenter, and every rendered row. */
  @cached
  get resolvedOptions(): SelectResolvedOptions {
    const args = this.#options.presentationOptions;
    return this.#customizations.resolveOptions(
      {
        caretIcon: args.caretIcon,
        iconOnly: args.iconOnly,
        ariaLabel: args.ariaLabel,
        placeholder: args.placeholder,
        searchPlaceholder: args.searchPlaceholder,
        searchIcon: args.searchIcon,
        loadingLabel: args.loadingLabel,
        icon: args.icon,
        showCaret: args.showCaret,
        clearable: args.clearable,
        noneLabel: args.noneLabel ?? this.#options.baseNoneLabel,
        disabled: args.disabled,
      },
      this.#options.kindOptions,
      {
        kind: this.kind,
        identifier: this.identifier,
        kindContext: this.#options.kindContext,
        instanceContext: this.#options.instanceContext,
        value: this.value,
        control: this.#control,
      }
    );
  }

  /** Whether anything is selected. */
  get hasValue(): boolean {
    return this.#selectionActions.hasValue;
  }

  /** Whether any non-null id in the normalized selection currently resolves as unresolved. */
  get hasUnresolvedSelection(): boolean {
    const value = this.value;
    const values = [...makeArray(value as SelectItemId | SelectItemId[])];
    return this.#valueResolver.hasUnresolved(values);
  }

  /** Whether the source is server-backed (drives debouncing). */
  get isAsync(): boolean {
    return this.#options.isAsync;
  }

  /** Whether the source's latest answer arrived without a promise. */
  get answersSynchronously(): boolean {
    return this.#source.answersSynchronously();
  }

  /** The minimum filter length before the list searches (`0` = no minimum). */
  get minChars(): number {
    return this.#options.minChars;
  }

  /**
   * Whether the current query is shorter than {@link minChars} — the "keep typing" state, in
   * which the list should not search. Reads the filter reactively, so the component's gate
   * re-evaluates as the user types. An empty query counts as below the threshold: with a
   * minimum set, opening should prompt for input, not load (and then hide) the whole list.
   */
  get belowMinChars(): boolean {
    return (
      this.#options.minChars > 0 &&
      this.#state.filter.length < this.#options.minChars
    );
  }

  /** How many more characters are needed to reach {@link minChars} (reactive). */
  get remainingMinChars(): number {
    return Math.max(0, this.#options.minChars - this.#state.filter.length);
  }

  /** The multi-select selection cap, or `null` when uncapped (always `null` for single). */
  get maximum(): number | null {
    return this.#selectionActions.maximum;
  }

  /** The advisory multi-select minimum (`0` = none, and always `0` for single). */
  get minimum(): number {
    return this.#selectionActions.minimum;
  }

  /**
   * Whether the selection has reached {@link maximum}. At the cap no further item can be
   * added, and every unselected ordinary option reports itself disabled.
   */
  get atMaximum(): boolean {
    return this.#selectionActions.atMaximum;
  }

  /** Whether the selection is still short of the advisory {@link minimum}. */
  get belowMinimum(): boolean {
    return this.#selectionActions.belowMinimum;
  }

  /** How many more items may still be added, or `undefined` when uncapped. */
  get remaining(): number | undefined {
    return this.#selectionActions.remaining;
  }

  /** Whether this is a multi-select. */
  get multiple(): boolean {
    return this.#options.multiple;
  }

  /** The recipe or family name captured at construction. */
  get kind(): string | undefined {
    return this.#options.kind;
  }

  /** Compatibility aliases captured at construction; never customization keys. */
  get legacyKinds(): readonly string[] {
    return this.#legacyKinds;
  }

  /** The call-site name captured at construction. */
  get identifier(): string | undefined {
    return this.#options.identifier;
  }

  /** The live handle for action rows and content, options, load, and change customizations. */
  get control(): SelectControl {
    return this.#control;
  }

  /** Whether asynchronous update work is in flight. */
  get pending(): boolean {
    return this.#selectionUpdates.pending;
  }

  /**
   * Read-only handles the `modifySelectKit` compat bridge needs to build its facade
   * (owner, a live element accessor, a teardown check). Supplied by the component; not
   * part of the consumer-facing API.
   */
  get legacyContext(): SelectLegacyContext | null {
    return this.#options.legacy;
  }

  /**
   * A stable-until-invalidated context object for the list `DAsyncContent`. Its identity
   * changes when the filter, reload nonce, reveal cursor, or the effective local items
   * change, which is what makes the list re-fetch.
   *
   * `items` is read synchronously here on purpose: a client source that changes must restart
   * the list even on the debounced path, where the async function runs outside the cached
   * computation and so cannot autotrack the source itself. Reading it in this `@cached` getter
   * folds the items dependency into the context identity. Empty (and cheap) for a server source.
   */
  @cached
  get loadContext(): {
    filter: string;
    nonce: number;
    reveal: number;
    items: readonly SelectItem[];
  } {
    return {
      filter: this.#state.filter,
      nonce: this.#state.nonce,
      reveal: this.#source.revealToken(),
      items: this.#source.reactiveItems(),
    };
  }

  /**
   * The client list after `filterBy`. Deriving this is the engine's job, so it is exposed
   * rather than recomputed by each caller — and it is `@cached` so `total` and `loadItems`
   * share one filter pass per render instead of each walking the list again. Empty for a
   * server source.
   */
  @cached
  get filteredItems(): readonly SelectItem[] {
    // Copied AND frozen. With no filter `filterLocal` passes the consumer's own array
    // straight through, and `readonly` is erased at runtime — but copying alone is not
    // enough either, because `@cached` hands the same array to every reader in the render,
    // so mutating it would corrupt what the engine itself reads next. Matches `buildItems`,
    // which also yields a frozen projection.
    return Object.freeze([...filterLocal(this.#options, this.#state.filter)]);
  }

  /** Whether the current source can fetch another page within any configured ceiling. */
  get canRevealMore(): boolean {
    return this.#source.canRevealMore();
  }

  /** Whether rendering stopped at the cap while the source still has more results. */
  get atCapWithMore(): boolean {
    return this.#source.atCapWithMore();
  }

  /**
   * The true result count when the source makes it knowable.
   *
   * A reported `total` outranks the count of rows actually navigable, deliberately: the engine
   * cannot tell an honest total whose tail it has not fetched from an inflated one, so it
   * trusts the source. A source that declares 500 and holds 90 therefore reports 500.
   * Unavailable after consecutive reveals fail to add visible rows for the query.
   */
  get total(): number | undefined {
    return this.#source.total();
  }

  /**
   * How many SOURCE options are currently loaded — excludes specials and the create row, so it
   * shares `total`'s population and a footer's `total - loadedCount` is a valid "how many more".
   * Reads the live source count (a client source has them all; a paginating source has its
   * accumulated page count), so it stays correct even while the list is unmounted (min-chars /
   * error), unlike a render-time count of navigable rows.
   */
  get loadedCount(): number {
    return this.#options.isAsync
      ? this.#state.serverLoadedCount
      : (this.total ?? 0);
  }

  /**
   * Whether a **reload** of an already-settled list is in flight — a new query, a
   * `reload()`, or a reveal — which is what `aria-busy` on the retained listbox reports.
   * The *initial* load is deliberately not pending: the listbox does not exist yet then,
   * its loading block does.
   *
   * Derived from tracked state rather than an imperative flag, because the flag would have
   * to be raised synchronously inside `loadItems`, which runs during render, and so could
   * never invalidate a consumer that had already read it — `aria-busy` would switch off
   * but never on.
   */
  get serverPending(): boolean {
    return this.#source.pending();
  }

  /** Whether a server source has not finished its first page yet. */
  get serverAwaitingFirstPage(): boolean {
    return this.#source.awaitingFirstPage();
  }

  /**
   * Whether the in-flight load is fetching more rows for the query already on screen rather
   * than replacing them for a new one. Both retain the old rows, so only this tells them apart.
   */
  get serverRevealPending(): boolean {
    return this.#source.revealPending();
  }

  /**
   * Whether the in-flight load answers a new filter, the only load that waits for the
   * debounce. A reveal or a reload keeps the filter and starts at once.
   */
  get serverQueryPending(): boolean {
    return this.#source.queryPending();
  }

  /**
   * Finds the first value added and removed between two selections, comparing ids by
   * `String(value)`.
   */
  diffValues(
    previous: SelectItemId[],
    next: SelectItemId[]
  ): {
    added: SelectItemId | undefined;
    removed: SelectItemId | undefined;
  } {
    return this.#selectionActions.diffValues(previous, next);
  }

  /**
   * Whether an item is currently selected, comparing its `valueField` id against the
   * controlled value.
   */
  @bind
  isSelected(item: SelectItem): boolean {
    return this.#selectionActions.isSelected(item);
  }

  /**
   * The async-data function for the list `DAsyncContent`. Returns the full filtered local
   * list or the accumulated server pages, bounded by `maxLoaded` when configured.
   *
   * @param _context - Reactivity trigger only; unused.
   * @returns Items, or a promise of items.
   */
  @bind
  loadItems(
    _context: unknown,
    opts: SelectLoadOptions = {}
  ): SelectItem[] | Promise<SelectItem[]> {
    this.#assertSingleSource();
    return this.#source.rows(opts);
  }

  /**
   * Requests another page when the source can reveal one.
   *
   * @returns Whether the reveal cursor advanced.
   */
  @bind
  revealMore(): boolean {
    return this.#source.revealMore();
  }

  /**
   * Builds the final rendered item list from the source's resolved items: applies
   * content customizations, groups the options, and prepends special and create items.
   *
   * @param rawItems - The items resolved by the source.
   * @param filter - The query that produced these rows, retained for create checks during a reload.
   * @returns The frozen list of normalized descriptors to render.
   */
  @bind
  buildItems(
    rawItems: SelectItem[] = [],
    filter = this.filter
  ): readonly SelectDescriptor[] {
    return this.#listComposer.buildItems(rawItems, filter);
  }

  /**
   * Normalizes arbitrary items into the frozen descriptor shape used for rendering.
   *
   * @param items - The items to normalize.
   */
  @bind
  describeItems(items: SelectItem[]): readonly SelectDescriptor[] {
    return this.#listComposer.describeItems(items);
  }

  /**
   * Resolves a value to its display item(s) for the trigger `DAsyncContent`. Returns
   * synchronously (no skeleton) when every id is covered by `valueItems`,
   * the resolve cache, or the client list; otherwise returns a promise. A held id that
   * cannot resolve maps to a synthetic `__unresolved` fallback (never `undefined`, never a
   * rejection, whether the resolver throws or rejects); only an empty value (null single /
   * empty multi) yields `undefined`, so the trigger shows its placeholder.
   *
   * Both arities share one path: single is a batch of one, narrowed back to a bare item so
   * the trigger never sees a one-element array. Whatever the sync ladder doesn't already
   * know resolves in a single call.
   *
   * @param value - The value (an id, or an array of ids).
   */
  @bind
  resolveSelection(
    value: SelectValue,
    opts: SelectLoadOptions = {}
  ):
    | SelectItem
    | SelectItem[]
    | Promise<SelectItem>
    | Promise<SelectItem[]>
    | Promise<void>
    | undefined {
    return (
      this.#selectionUpdates.done ??
      this.#valueResolver.resolveSelection(value, opts)
    );
  }

  /**
   * The item to display for a single value without awaiting — including the `__unresolved`
   * fallback once an attempt has failed, so a trigger can tell "failed" (render the
   * fallback) from "still resolving" (`undefined`, render nothing).
   *
   * @param value - The single value; an array or `null` yields `undefined`.
   */
  resolveSingleSync(value: SelectValue): SelectItem | undefined {
    return this.#valueResolver.resolveSingleSync(value);
  }

  getItemLabel(item: SelectItem | null | undefined): string {
    return selectItemLabel(item, this.#options.labelField);
  }

  /**
   * The text that stands for a held item on every surface: the trigger, chips, the typeahead
   * input, the accessible names built from them, and announcements. An unresolved item named by
   * `createUnresolvedItem` keeps that name, which already explains itself; the default fallback
   * reads as an unknown item with its id, since nothing more is known about it.
   *
   * @param item - The held item, resolved or not.
   * @returns The label to show and announce.
   */
  @bind
  getSelectionLabel(item: SelectItem | null | undefined): string {
    if (item?.__unresolved && !this.isCustomUnresolvedItem(item)) {
      return i18n("d_select.unresolved_value", {
        value: String(item[this.#options.valueField] ?? ""),
      });
    }
    return this.getItemLabel(item);
  }

  getSingleSelectionLabel(value: SelectValue): string {
    if (value == null || Array.isArray(value)) {
      return "";
    }

    return this.getItemLabel(this.#valueResolver.resolveOneSync(value));
  }

  /**
   * Option-row presentation from render-time customizations. Each evaluation starts fresh
   * so classes and titles cannot leak between rows or renders.
   */
  @bind
  rowPresentation(descriptor: SelectDescriptor): SelectRowPresentation {
    return this.#customizations.applyRow({
      item: descriptor.item,
      selected: descriptor.flags.selected,
      disabled: descriptor.flags.disabled,
      ...this.#extensionContext(),
    });
  }

  /**
   * Whether this fallback came from `createUnresolvedItem` rather than the built-in bare-id
   * default. Lets a trigger that can only render a string decide whether to append its own
   * "unavailable" wording: a named fallback ("Topic #123") already reads as one, a bare id
   * does not. Identity-based, so a builder that throws — caught, yielding the default — is
   * correctly reported as NOT custom.
   *
   * @param item - The item to test; only meaningful for an `__unresolved` fallback.
   */
  isCustomUnresolvedItem(item: SelectItem): boolean {
    return this.#valueResolver.isCustomUnresolvedItem(item);
  }

  /**
   * Sets the filter term (re-runs the list search).
   */
  @bind
  setFilter(term: string): void {
    const filter = term ?? "";
    if (filter === this.#state.filter) {
      return;
    }

    this.#source.reset();
    this.#state.filter = filter;
  }

  /**
   * Activates an item: runs its `onSelect` callback if present (an action item that
   * never becomes a value and does not close the overlay), otherwise toggles it.
   */
  @bind
  activate(item: SelectItem): void {
    this.#selectionActions.activate(item);
  }

  /**
   * Toggles an item: for multi, selects or deselects; for single, selects it.
   */
  @bind
  toggle(item: SelectItem): void {
    this.#selectionActions.toggle(item);
  }

  /**
   * Selects an item: caches it for synchronous display, computes the next value, and
   * emits `onChange`. For single-select it also requests the overlay to close (when
   * `closeOnSelect`). Never mutates the value — the parent does, via `onChange`.
   */
  @bind
  select(item: SelectItem, origin?: SelectionOrigin): void {
    this.#selectionActions.select(item, origin);
  }

  /**
   * Adds eligible items with one middleware run and emit, up to the remaining capacity.
   * Skips held, duplicate, disabled, action and structural items. Single-select picks
   * the first new eligible item. Even an empty batch supersedes older update intent.
   */
  @bind
  selectMany(items: readonly SelectItem[], origin?: SelectionOrigin): void {
    this.#selectionActions.selectMany(items, origin);
  }

  /**
   * Removes an item from the selection (emits the next value).
   */
  @bind
  deselect(item: SelectItem, origin?: SelectionOrigin): void {
    this.#selectionActions.deselect(item, origin);
  }

  /** Removes the last held value from a multi-select selection. */
  @bind
  deselectLast(origin?: SelectionOrigin): void {
    this.#selectionActions.deselectLast(origin);
  }

  /**
   * Clears the entire selection (emits an empty value).
   */
  @bind
  clear(origin?: SelectionOrigin): void {
    this.#selectionActions.clear(origin);
  }

  /** Revokes update authority when newer interaction intent takes over. */
  supersedeUpdate(): void {
    this.#selectionUpdates.supersede();
  }

  /** Runs event-time work with a scope owned by this update. */
  update(
    work: (scope: SelectUpdateScope) => void | Promise<void>
  ): Promise<void> {
    return this.#selectionUpdates.update(work);
  }

  /**
   * Resets the source and forces a re-fetch even when the filter is unchanged. Also
   * drops failed value-resolution fallbacks so they are attempted again; successful items
   * stay cached.
   */
  @bind
  reload(options?: SelectReloadOptions): void {
    this.#valueResolver.evictUnresolved();
    this.#reloadList();
    this.#immediateQueryKey = options?.immediate ? this.queryKey : null;
  }

  /** Checks live loader inputs at event time; never call during render. */
  reloadIfContextChanged(): void {
    if (isDestroying(this) || this.#requestContextQuery !== this.queryKey) {
      return;
    }
    const context = this.#getLoadContext() ?? {};
    const snapshot = this.#requestLoadContext ?? {};
    const keys = Reflect.ownKeys(context);
    if (
      keys.length !== Reflect.ownKeys(snapshot).length ||
      keys.some(
        (key) =>
          !Object.hasOwn(snapshot, key) ||
          this.#contextEntryChanged(key, Reflect.get(context, key), snapshot)
      )
    ) {
      this.#reloadList();
    }
  }

  /**
   * Asks the overlay to close (wired by the component). Used by action items and the
   * compat bridge's `selectKit.close()`.
   */
  @bind
  requestClose(): void {
    this.#options.requestClose?.();
  }

  #contextEntryChanged(
    key: PropertyKey,
    value: unknown,
    snapshot: Readonly<Record<string, unknown>>
  ): boolean {
    const copy = this.#requestContextArrays.get(key);
    if (!copy) {
      return !Object.is(value, Reflect.get(snapshot, key));
    }
    return (
      !Array.isArray(value) ||
      value.length !== copy.length ||
      value.some((element, index) => !Object.is(element, copy[index]))
    );
  }

  /** The static names and live data shared by select customizations. */
  #extensionContext(): SelectResolvedContext {
    return {
      kind: this.kind,
      identifier: this.identifier,
      kindContext: this.#options.kindContext,
      instanceContext: this.#options.instanceContext,
      options: this.resolvedOptions,
    };
  }

  /** Reloads only the list, preserving held-value fallbacks and pending update authority. */
  #reloadList(): void {
    this.#onReloadList?.();
    this.#source.reset();
    this.#state.nonce++;
  }

  /** Resolves the loader outside render when a query's first request starts. */
  #resolveLoad(filter: string): NonNullable<SelectEngineOptions["load"]> {
    const context = this.#getLoadContext() ?? {};
    const snapshot: Readonly<Record<string, unknown>> = Object.freeze(
      Object.fromEntries(
        Reflect.ownKeys(context).map((key) => [key, Reflect.get(context, key)])
      )
    );
    this.#requestLoadContext = snapshot;
    this.#requestContextArrays = new Map(
      Reflect.ownKeys(snapshot).flatMap((key) => {
        const value: unknown = Reflect.get(snapshot, key);
        return Array.isArray(value) ? [[key, [...value]] as const] : [];
      })
    );
    this.#requestContextQuery = this.queryKey;
    const load = this.#customizations.applyLoad(this.#options.load!, {
      loadContext: snapshot,
      filter,
      ...this.#extensionContext(),
      control: this.#control,
    });
    return (query, opts) =>
      load(query, {
        ...opts,
        context: snapshot,
        options: this.resolvedOptions,
      });
  }

  // `items` and `load` are mutually exclusive; the construction-time source kind wins.
  // Warns once when both are supplied — checked here rather than only in the constructor
  // because a live `items` source can turn non-empty after construction.
  #assertSingleSource(): void {
    if (this.#dualSourceWarned || !this.#options.isAsync) {
      return;
    }
    // Runs inside the list's load, so its reads must not become reload inputs: resolving the
    // options reads the recipe's context and presentation arguments, and a change to any of them
    // would cancel the page in flight.
    const local = untrack(() =>
      typeof this.#options.items === "function"
        ? this.#options.items(this.resolvedOptions)
        : this.#options.items
    );
    if (local != null && (makeArray(local) as SelectItem[]).length > 0) {
      this.#dualSourceWarned = true;
      // eslint-disable-next-line no-console
      console.warn(
        "DSelect: `@items` and `@load` are mutually exclusive; `@load` takes precedence and `@items` is ignored."
      );
    }
  }
}
