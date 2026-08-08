import { cached } from "@glimmer/tracking";
import type Owner from "@ember/owner";
import { bind } from "discourse/lib/decorators";
import { makeArray } from "discourse/lib/helpers";
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
   * it. The first argument is the engine on the native path, or the legacy select-kit
   * facade on the compat-bridge path, so it is deliberately untyped.
   */
  onSelect?: (engine: unknown, item: SelectItem) => void;

  /** When true, the item cannot be activated (guards both pointer and keyboard). */
  disabled?: boolean;

  /** Marks the synthetic create-on-the-fly item. */
  __create?: boolean;

  /** Marks a synthetic fallback for a held value that could not be resolved. */
  __unresolved?: boolean;

  /**
   * Marks a synthetic group-header row (engine-injected from `groupBy`). A structural row:
   * it is never selectable, navigable, or counted in the option set. Carries its `label`.
   */
  __header?: boolean;

  /**
   * Marks an engine-injected divider for an unlabeled group boundary. `groupBy` injects it when
   * `groupLabel` returns nullish for the segment; consumers never set it.
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
  /** Stable `{{#each}}` key — the normalized value, or a synthetic key for a value-less row. */
  key: string;
  /** The row's id (raw, from `valueField`). */
  value: SelectItemId;
  /** The raw model, passed through untouched to consumer blocks. */
  item: SelectItem;
  /** Row state, centralized so the template and option component don't re-derive it. */
  flags: {
    /** Whether this row's value is part of the current selection. */
    selected: boolean;
    /** Whether the row cannot be activated (guards both pointer and keyboard). */
    disabled: boolean;
    /**
     * A group-header row: structural, so it is skipped by selection, navigation, and the
     * option-position math (no `posInSet`/`setSize`). Rendered outside the option set.
     */
    group: boolean;
    /** A divider row: structural like a header, but presentational and label-less. */
    divider: boolean;
    /** Marks the synthetic create-on-the-fly row. */
    __create: boolean;
    /** True for an unresolved held value; false on list rows. */
    __unresolved: boolean;
    /** True for the injected single-select "none" row (a selectable row that clears the value). */
    __none: boolean;
  };
  /**
   * Zero-based position among navigable list options. Structural and disabled rows leave it
   * undefined, as does the trigger/chip descriptor path.
   */
  logicalIndex?: number;
  /**
   * Zero-based group-header ordinal. A header carries its own ordinal and following options
   * inherit it until a divider or another header ends the run. Ungrouped rows leave it undefined.
   */
  groupOrdinal?: number;
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
  /** Maximum page length requested from a paginated source. */
  limit?: number;
  /** Raw source offset for a paginated request. */
  offset?: number;
  /** Cancels a superseded request. */
  signal?: AbortSignal;
}

/** A page from a server-backed source, with optional pagination metadata. */
export interface SelectLoadResponse {
  /** The page returned for the requested offset. */
  items: SelectItem[];
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

/**
 * Constructor options for a {@link SelectEngine}.
 *
 * Function-valued options are invoked with an unspecified receiver — read the provided
 * arguments, never `this`. Where a callback needs the engine, it is passed explicitly
 * (see {@link SelectItem#onSelect}).
 *
 * The `get*` reader options are the live counterparts of the plain option beside each: when
 * supplied they are read on every access, so a runtime change to the underlying `@arg`
 * propagates, while the plain static option is a construction-time snapshot for direct,
 * non-reactive consumers. A component wires these to its live args; the engine re-applies
 * each default on read.
 */
export interface SelectEngineOptions {
  /** Multi-select when true (drives value shape, chips, and close-on-select). */
  multiple?: boolean;

  /**
   * `() => value` — reads the controlled value live (single: an id or `null`; multi: an
   * id array). Defaults to always-`null`.
   */
  getValue?: () => SelectValue;

  /** Live reader for {@link multiple}. */
  getMultiple?: () => boolean | undefined;

  /** Live reader for {@link minChars}. */
  getMinChars?: () => number | undefined;

  /** Live reader for {@link maximum}. */
  getMaximum?: () => number | undefined;

  /** Live reader for {@link minimum}. */
  getMinimum?: () => number | undefined;

  /** Live reader for {@link noneLabel}. */
  getNoneLabel?: () => string | undefined;

  /** Live reader for {@link valueItems}. */
  getValueItems?: () => SelectItem | SelectItem[] | undefined;

  /** Live reader for {@link allowCreate}. */
  getAllowCreate?: () =>
    | boolean
    | ((filter: string, items: SelectItem[]) => boolean)
    | undefined;

  /** Keys plugin `select-content` transformers match on. */
  identifiers?: string | string[];

  /**
   * A static array (or `() => array`) of items — the client-only source. Provide this
   * or `load`, not both.
   */
  items?: SelectItem[] | (() => SelectItem[] | null | undefined);

  /**
   * `(filter, { signal, offset, limit }) => items | { items, total?, hasMore? }`,
   * synchronously or as a promise. Pagination starts without a limit so the source defines
   * its page size.
   *
   * A response that declares neither `total` nor `hasMore` — including a bare array — is
   * taken as the complete set, so a paginating source **must** declare one of them or only
   * its first page is ever shown.
   */
  load?: (
    filter: string,
    opts: SelectLoadOptions
  ) => SelectLoadResult | Promise<SelectLoadResult>;

  /**
   * Client-filter field name or `(item, term) => boolean`. Defaults to a substring
   * match on `labelField`.
   */
  filterBy?: string | ((item: SelectItem, term: string) => boolean);

  /**
   * Minimum filter length before the list searches. `0` (default) searches on any input.
   * A query shorter than this — including the empty query — is "below threshold": the list
   * issues no source call and the component shows a keep-typing hint. See
   * {@link SelectEngine#belowMinChars}.
   */
  minChars?: number;

  /**
   * Hard cap on a multi-select's selection count. Ignored when not `multiple`, and treated as
   * unset below `1`. At the cap every add is refused — pointer, keyboard, create-on-the-fly and
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
  maximum?: number;

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
   * `(value, { signal }) => item | Promise<item>`, used to resolve a value id to its
   * display item when it isn't already known.
   */
  resolveValue?: (
    value: SelectItemId,
    opts: SelectLoadOptions
  ) => SelectItem | Promise<SelectItem | undefined> | undefined;

  /**
   * Batch counterpart to `resolveValue` for multi-select: `(values, { signal }) => items |
   * Promise<items>`. The engine calls it once for the uncached ids (cached / seeded ids are
   * skipped) so N chips never mean N requests. Omitted or errored ids become fallbacks.
   */
  resolveValues?: (
    values: SelectItemId[],
    opts: SelectLoadOptions
  ) => SelectItem[] | Promise<SelectItem[]>;

  /**
   * Enables the create-on-the-fly item; a function `(filter, items) => boolean` gates it
   * dynamically.
   */
  allowCreate?: boolean | ((filter: string, items: SelectItem[]) => boolean);

  /**
   * `(filter) => item` producing the synthetic "create" item (conventionally marked
   * `__create: true`).
   */
  createItem?: (filter: string) => SelectItem;

  /**
   * `(value) => item` producing the fallback for a held id that could not be resolved,
   * so a preset can name it (e.g. `Topic #123`) instead of showing the bare id. The
   * engine marks the result `__unresolved` regardless of what the builder returns.
   * Defaults to the id itself on `labelField`.
   */
  createUnresolvedItem?: (value: SelectItemId) => SelectItem;

  /**
   * `(snapshot) => item[]` prepended to the list (e.g. a "none"/"uncategorized" item).
   */
  specialItems?: (snapshot: SelectSnapshot) => SelectItem[];

  /**
   * Groups the filtered options by a field name or `(item) => key`. Each group's label
   * determines whether its boundary is a header or an unlabeled splitter; a leading splitter
   * is suppressed. Client sources only; a source that pages ignores it because a group can
   * span pages.
   */
  groupBy?: string | ((item: SelectItem) => SelectItemId);

  /**
   * Maps a group key to its header text. A nullish result renders that boundary as an
   * unlabeled splitter; when omitted, every boundary is a splitter.
   */
  groupLabel?: (key: SelectItemId) => string | null | undefined;

  /** Whether choosing an item closes the overlay. Defaults to `!multiple`. */
  closeOnSelect?: boolean;

  /**
   * `(nextValue, item|items) => void`, where `nextValue` is the id(s) and the second arg
   * is the resolved item(s), each matching the arity. The parent applies `nextValue` to
   * `@value`.
   */
  onChange?: (
    nextValue: SelectValue,
    item: SelectItem | SelectItem[] | null
  ) => void;

  /**
   * Called by the engine to ask the overlay to close (wired by the component to the menu
   * instance).
   */
  requestClose?: () => void;

  /**
   * Handles for the `modifySelectKit` compat bridge, supplied by the component:
   * `{ owner, getElement, isDestroyed }`. Only needed when the select carries
   * identifiers that legacy extensions may target.
   */
  legacy?: SelectLegacyContext | null;
}

/**
 * Headless, DOM-free controller for the ui-kit select family. It is **controlled**:
 * the parent owns the value (`@value`), which the engine reads live via a `getValue`
 * thunk and never stores. The engine owns only internal UI state — the filter, a
 * reload nonce, and a resolved-item cache — plus the selection *logic*: it derives
 * `isSelected`/display from the value, builds the rendered item list (plugin
 * transformers + create-on-the-fly + special items), resolves a value id to its
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
  #valueResolver: ValueResolver;
  #selectionActions: SelectionActions;
  #listComposer: ListComposer;
  #source!: SelectSource;

  /**
   * @param opts - The engine's configuration; every field is documented on
   *   {@link SelectEngineOptions}.
   */
  constructor(opts: SelectEngineOptions = {}) {
    this.#options = new SelectOptionsView(opts);
    this.#valueResolver = new ValueResolver({
      options: this.#options,
      knownRows: () => this.#source.knownRows(),
    });
    this.#selectionActions = new SelectionActions({
      options: this.#options,
      runActionItem: (item) => item.onSelect!(this, item),
      cacheResolved: (item) => this.#valueResolver.cacheResolved(item),
      resolveOneSync: (value) => this.#valueResolver.resolveOneSync(value),
      applyLegacyOnChange: (value, payload) =>
        applyLegacySelectKitOnChange(this, value, payload),
    });
    this.#listComposer = new ListComposer({
      options: this.#options,
      getFilter: () => this.#state.filter,
      getValue: () => this.value,
      getHasValue: () => this.hasValue,
      isSelected: (item) => this.isSelected(item),
      getAtMaximum: () => this.atMaximum,
      getTotal: () => this.total,
      applyLegacyContent: (items) => applyLegacySelectKitContent(this, items),
    });
    this.#source = this.#options.load
      ? new PagedSource({
          load: this.#options.load,
          state: this.#state,
          keyOf: (item) =>
            this.#options.valueKey(this.#options.itemValue(item)),
        })
      : new LocalSource({
          filtered: () => this.filteredItems,
          all: () => localItems(this.#options),
        });
    // Catch a both-sources misconfiguration up front (before any menu opens); the same
    // check also runs per load for a live `items` source that turns non-empty later.
    this.#assertSingleSource();
  }

  /** The current filter term. */
  get filter(): string {
    return this.#state.filter;
  }

  /**
   * The controlled value, normalized. Not cached: it reads the live `getValue` thunk
   * so it always reflects the parent's `@value` (which is what makes the component
   * controlled). For a stable `@context` identity, feed the raw `@value` to the trigger
   * rather than this getter.
   *
   * @returns A frozen id array (multiple) or a single id / `null`.
   */
  get value(): SelectValue {
    return this.#selectionActions.value;
  }

  /** Whether anything is selected. */
  get hasValue(): boolean {
    return this.#selectionActions.hasValue;
  }

  /** Whether any non-null id in the normalized selection currently resolves as unresolved. */
  get hasUnresolvedSelection(): boolean {
    const value = this.value;
    const values = this.multiple
      ? [...(value as readonly SelectItemId[])]
      : value == null
        ? []
        : [value];
    return this.#valueResolver.hasUnresolved(values);
  }

  /** Whether the source is server-backed (drives debouncing). */
  get isAsync(): boolean {
    return this.#options.isAsync;
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

  /** The transformer identifiers. */
  get identifiers(): string[] {
    return this.#options.identifiers;
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

  /** Whether the current source has another page available below the cap. */
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

  /**
   * Whether the in-flight load is fetching more rows for the query already on screen rather
   * than replacing them for a new one. Both retain the old rows, so only this tells them apart.
   */
  get serverRevealPending(): boolean {
    return this.#source.revealPending();
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
   * list or the accumulated server pages, bounded by the server cap.
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
   * Requests another page when the source can reveal one below the cap.
   *
   * @returns Whether the reveal cursor advanced.
   */
  @bind
  revealMore(): boolean {
    return this.#source.revealMore();
  }

  /**
   * Builds the final rendered item list from the source's resolved items: applies
   * plugin `select-content` transformers, groups the options, appends the create-on-the-fly
   * item, and prepends any special items.
   *
   * @param rawItems - The items resolved by the source.
   * @returns The frozen list of normalized descriptors to render.
   */
  @bind
  buildItems(rawItems: SelectItem[] = []): readonly SelectDescriptor[] {
    return this.#listComposer.buildItems(rawItems);
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
    | undefined {
    return this.#valueResolver.resolveSelection(value, opts);
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

  getSingleSelectionLabel(value: SelectValue): string {
    if (value == null || Array.isArray(value)) {
      return "";
    }

    return this.getItemLabel(this.#valueResolver.resolveOneSync(value));
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
  select(item: SelectItem): void {
    this.#selectionActions.select(item);
  }

  /**
   * Removes an item from the selection (emits the next value).
   */
  @bind
  deselect(item: SelectItem): void {
    this.#selectionActions.deselect(item);
  }

  /** Removes the last held value from a multi-select selection. */
  @bind
  deselectLast(): void {
    this.#selectionActions.deselectLast();
  }

  /**
   * Clears the entire selection (emits an empty value).
   */
  @bind
  clear(): void {
    this.#selectionActions.clear();
  }

  /**
   * Resets the source and forces a re-fetch even when the filter is unchanged. Also
   * drops failed value-resolution fallbacks so they are attempted again; successful items
   * stay cached.
   */
  @bind
  reload(): void {
    this.#valueResolver.evictUnresolved();
    this.#source.reset();
    this.#state.nonce++;
  }

  /**
   * Asks the overlay to close (wired by the component). Used by action items and the
   * compat bridge's `selectKit.close()`.
   */
  @bind
  requestClose(): void {
    this.#options.requestClose?.();
  }

  // `items` and `load` are mutually exclusive; the construction-time source kind wins.
  // Warns once when both are supplied — checked here rather than only in the constructor
  // because a live `items` source can turn non-empty after construction.
  #assertSingleSource(): void {
    if (this.#dualSourceWarned || !this.#options.isAsync) {
      return;
    }
    const local =
      typeof this.#options.items === "function"
        ? this.#options.items()
        : this.#options.items;
    if (local != null && (makeArray(local) as SelectItem[]).length > 0) {
      this.#dualSourceWarned = true;
      // eslint-disable-next-line no-console
      console.warn(
        "DSelect: `@items` and `@load` are mutually exclusive; `@load` takes precedence and `@items` is ignored."
      );
    }
  }
}
