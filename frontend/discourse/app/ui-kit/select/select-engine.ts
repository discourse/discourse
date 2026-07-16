import { cached, tracked } from "@glimmer/tracking";
import type Owner from "@ember/owner";
import { trackedMap } from "@ember/reactive/collections";
import { bind } from "discourse/lib/decorators";
import { makeArray } from "discourse/lib/helpers";
import {
  applyBehaviorTransformer,
  applyValueTransformer,
} from "discourse/lib/transformer";
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
    /** Reserved for group headers (Decision 2); always false today. */
    group: boolean;
    /** Marks the synthetic create-on-the-fly row. */
    __create: boolean;
    /** True for an unresolved held value; false on list rows. */
    __unresolved: boolean;
  };
}

export function selectItemLabel(
  item: SelectItem | null | undefined,
  labelField = "name"
): string {
  return String(item?.[labelField] ?? "");
}

/** Options threaded into a source (`load` / `resolveValue`) call. */
export interface SelectLoadOptions {
  signal?: AbortSignal;
}

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

/** Constructor options for a {@link SelectEngine}. */
export interface SelectEngineOptions {
  /** Multi-select when true (drives value shape, chips, and close-on-select). */
  multiple?: boolean;

  /**
   * `() => value` — reads the controlled value live (single: an id or `null`; multi: an
   * id array). Defaults to always-`null`.
   */
  getValue?: () => SelectValue;

  /** Keys plugin `select-content` transformers match on. */
  identifiers?: string | string[];

  /**
   * A static array (or `() => array`) of items — the client-only source. Provide this
   * or `load`, not both.
   */
  items?: SelectItem[] | (() => SelectItem[] | null | undefined);

  /**
   * `(filter, { signal }) => items | Promise<items>`. Returning an array is a
   * synchronous/client source; a promise is server-backed.
   */
  load?: (
    filter: string,
    opts: SelectLoadOptions
  ) => SelectItem[] | Promise<SelectItem[]>;

  /**
   * Client-filter field name or `(item, term) => boolean`. Defaults to a substring
   * match on `labelField`.
   */
  filterBy?: string | ((item: SelectItem, term: string) => boolean);

  /** Field holding an item's value. Defaults to `"id"`. */
  valueField?: string;

  /** Field holding an item's label. Defaults to `"name"`. */
  labelField?: string;

  /**
   * Already-resolved item(s) for the current value, so the trigger needs no fetch to
   * display them.
   */
  selected?: SelectItem | SelectItem[];

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
 * Private, fixed-shape reactive state for a {@link SelectEngine}. Declaring the fields
 * on a small class (rather than a `trackedObject`) enforces the shape and keeps
 * standard `@tracked` semantics; the instance is held in a `#`-private field, so it is
 * unreachable from outside the engine. Note there is deliberately no `selection` here:
 * the value is controlled by the parent (see {@link SelectEngine}).
 */
class SelectState {
  /** The current filter/search term. */
  @tracked filter = "";

  /**
   * Bumped by {@link SelectEngine#reload} to force the list to re-fetch even when the
   * filter is unchanged (e.g. an "AI suggestions" flow).
   */
  @tracked nonce = 0;
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

  /**
   * value → resolved item, so a re-render or reopen never re-fetches a label. Keyed by the
   * normalized value (see `#valueKey`) so a string/number id mismatch is a cache hit.
   */
  #resolvedCache = trackedMap<string, SelectItem>();

  /**
   * The same, for outcomes a synchronous resolver produced, which the trigger still has to
   * read later in the same render. Deliberately untracked: `#resolveMany` runs during a
   * render that already consumed `#resolvedCache`, so writing that tracked map here would
   * invalidate the very computation performing the write.
   */
  #synchronousOutcomes = new Map<string, SelectItem>();

  // Fallback items that were actually produced by `createUnresolvedItem`.
  #customUnresolvedItems = new WeakSet<SelectItem>();

  #multiple: boolean;
  #identifiers: string[];
  #valueField: string;
  #labelField: string;
  #filterBy?: string | ((item: SelectItem, term: string) => boolean);
  #items?: SelectItem[] | (() => SelectItem[] | null | undefined);
  #load?: (
    filter: string,
    opts: SelectLoadOptions
  ) => SelectItem[] | Promise<SelectItem[]>;
  #selected?: SelectItem | SelectItem[];
  #resolveValue?: (
    value: SelectItemId,
    opts: SelectLoadOptions
  ) => SelectItem | Promise<SelectItem | undefined> | undefined;
  #resolveValues?: (
    values: SelectItemId[],
    opts: SelectLoadOptions
  ) => SelectItem[] | Promise<SelectItem[]>;
  #allowCreate?: boolean | ((filter: string, items: SelectItem[]) => boolean);
  #createItem?: (filter: string) => SelectItem;
  #createUnresolvedItem?: (value: SelectItemId) => SelectItem;
  #specialItems?: (snapshot: SelectSnapshot) => SelectItem[];
  #closeOnSelect: boolean;
  #onChange?: (
    nextValue: SelectValue,
    item: SelectItem | SelectItem[] | null
  ) => void;
  #requestClose?: () => void;
  #readValue: () => SelectValue;
  #isAsync: boolean;
  #legacy: SelectLegacyContext | null;

  /**
   * @param opts.multiple - Multi-select when true (drives value shape, chips, and
   *   close-on-select).
   * @param opts.getValue - `() => value` — reads the controlled value live (single: an
   *   id or `null`; multi: an id array). Defaults to always-`null`.
   * @param opts.identifiers - Keys plugin `select-content` transformers match on.
   * @param opts.items - A static array (or `() => array`) of items — the client-only
   *   source. Provide this or `load`, not both.
   * @param opts.load - `(filter, { signal }) => items | Promise<items>`. Returning an
   *   array is a synchronous/client source; a promise is server-backed.
   * @param opts.filterBy - Client-filter field name or `(item, term) => boolean`.
   *   Defaults to a substring match on `labelField`.
   * @param opts.valueField - Field holding an item's value. Defaults to `"id"`.
   * @param opts.labelField - Field holding an item's label. Defaults to `"name"`.
   * @param opts.selected - Already-resolved item(s) for the current value, so the
   *   trigger needs no fetch to display them.
   * @param opts.resolveValue - `(value, { signal }) => item | Promise<item>`, used to
   *   resolve a value id to its display item when it isn't already known.
   * @param opts.allowCreate - Enables the create-on-the-fly item; a function
   *   `(filter, items) => boolean` gates it dynamically.
   * @param opts.createItem - `(filter) => item` producing the synthetic "create" item
   *   (conventionally marked `__create: true`).
   * @param opts.specialItems - `(snapshot) => item[]` prepended to the list (e.g. a
   *   "none"/"uncategorized" item).
   * @param opts.closeOnSelect - Whether choosing an item closes the overlay. Defaults to
   *   `!multiple`.
   * @param opts.onChange - `(nextValue, item|items) => void`, where `nextValue` is the
   *   id(s) and the second arg is the resolved item(s), each matching the arity. The
   *   parent applies `nextValue` to `@value`.
   * @param opts.requestClose - Called by the engine to ask the overlay to close (wired
   *   by the component to the menu instance).
   * @param opts.legacy - Handles for the `modifySelectKit` compat bridge, supplied by
   *   the component: `{ owner, getElement, isDestroyed }`. Only needed when the select
   *   carries identifiers that legacy extensions may target.
   */
  constructor(opts: SelectEngineOptions = {}) {
    this.#multiple = opts.multiple ?? false;
    this.#identifiers = makeArray(opts.identifiers) as string[];
    this.#valueField = opts.valueField ?? "id";
    this.#labelField = opts.labelField ?? "name";
    this.#filterBy = opts.filterBy;
    this.#items = opts.items;
    this.#load = opts.load;
    this.#selected = opts.selected;
    this.#resolveValue = opts.resolveValue;
    this.#resolveValues = opts.resolveValues;
    this.#allowCreate = opts.allowCreate;
    this.#createItem = opts.createItem;
    this.#createUnresolvedItem = opts.createUnresolvedItem;
    this.#specialItems = opts.specialItems;
    this.#closeOnSelect = opts.closeOnSelect ?? !this.#multiple;
    this.#onChange = opts.onChange;
    this.#requestClose = opts.requestClose;
    this.#legacy = opts.legacy ?? null;
    // The controlled value is read live via this thunk, so the engine reflects the
    // parent's `@value` without storing any selection of its own.
    this.#readValue = opts.getValue ?? (() => null);
    this.#isAsync = typeof opts.load === "function";

    // Seed the resolved-item cache with any already-known items so the trigger can
    // display them synchronously (no fetch, no skeleton).
    for (const item of makeArray(opts.selected) as SelectItem[]) {
      this.#cacheResolved(item);
    }
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
    const raw = this.#readValue();
    return this.#multiple
      ? Object.freeze(this.#dedupeValues(makeArray(raw) as SelectItemId[]))
      : (raw ?? null);
  }

  /** Whether anything is selected. */
  get hasValue(): boolean {
    return this.#multiple ? this.#valueArray.length > 0 : this.value != null;
  }

  /** Whether the source is server-backed (drives debouncing). */
  get isAsync(): boolean {
    return this.#isAsync;
  }

  getItemLabel(item: SelectItem | null | undefined): string {
    return selectItemLabel(item, this.#labelField);
  }

  getSingleSelectionLabel(value: SelectValue): string {
    if (value == null || Array.isArray(value)) {
      return "";
    }

    return this.getItemLabel(this.#resolveOneSync(value));
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
    return this.#customUnresolvedItems.has(item);
  }

  /** Whether this is a multi-select. */
  get multiple(): boolean {
    return this.#multiple;
  }

  /** The transformer identifiers. */
  get identifiers(): string[] {
    return this.#identifiers;
  }

  /**
   * Read-only handles the `modifySelectKit` compat bridge needs to build its facade
   * (owner, a live element accessor, a teardown check). Supplied by the component; not
   * part of the consumer-facing API.
   */
  get legacyContext(): SelectLegacyContext | null {
    return this.#legacy;
  }

  /**
   * A stable-until-invalidated context object for the list `DAsyncContent`. Its
   * identity changes when the filter or the reload nonce changes, which is what makes
   * the list re-fetch.
   */
  @cached
  get loadContext(): { filter: string; nonce: number } {
    return { filter: this.#state.filter, nonce: this.#state.nonce };
  }

  /**
   * Whether an item is currently selected, comparing its `valueField` id against the
   * controlled value.
   */
  @bind
  isSelected(item: SelectItem): boolean {
    const key = this.#valueKey(this.#itemValue(item));
    if (key == null) {
      return false;
    }
    return this.#multiple
      ? this.#valueArray.some((v) => this.#valueKey(v) === key)
      : this.#valueKey(this.value) === key;
  }

  /**
   * The async-data function for the list `DAsyncContent`. Ignores the context arg (it
   * exists only to drive reactivity) and calls the normalized source with the live
   * filter, forwarding the abort signal.
   *
   * @param _context - Reactivity trigger only; unused.
   * @returns Items, or a promise of items.
   */
  @bind
  loadItems(
    _context: unknown,
    opts: SelectLoadOptions = {}
  ): SelectItem[] | Promise<SelectItem[]> {
    return this.#source(this.#state.filter, opts);
  }

  /**
   * Builds the final rendered item list from the source's resolved items: applies
   * plugin `select-content` transformers, appends the create-on-the-fly item, and
   * prepends any special items.
   *
   * @param rawItems - The items resolved by the source.
   * @returns The frozen list of normalized descriptors to render.
   */
  @bind
  buildItems(rawItems: SelectItem[] = []): readonly SelectDescriptor[] {
    let items: SelectItem[] = [...(makeArray(rawItems) as SelectItem[])];

    items = applyValueTransformer("select-content", items, {
      identifiers: this.#identifiers,
      filter: this.#state.filter,
      value: this.value,
    });

    // Legacy `modifySelectKit(id).{prepend,append,replace}Content` extensions run in
    // their own stage, after the native transformer, so ordering is deterministic and
    // does not depend on global transformer registration order.
    items = applyLegacySelectKitContent(this, items);

    if (this.#shouldOfferCreate(items)) {
      // `#shouldOfferCreate` already guaranteed a `#createItem` is present.
      items = [...items, this.#createItem!(this.#state.filter)];
    }

    const special = this.#specialItems?.(this.#snapshot()) ?? [];
    const finalItems = [...(makeArray(special) as SelectItem[]), ...items];

    // Normalize as the final step: everything above operates on raw items (so the
    // transformer / bridge / onSelect pipeline is unchanged); only the render array is wrapped.
    return this.describeItems(finalItems);
  }

  /**
   * Normalizes arbitrary items into the frozen descriptor shape used for rendering.
   *
   * @param items - The items to normalize.
   */
  @bind
  describeItems(items: SelectItem[]): readonly SelectDescriptor[] {
    return Object.freeze(
      items.map((item, index) => this.#normalize(item, index))
    );
  }

  /**
   * Resolves a value to its display item(s) for the trigger `DAsyncContent`. Returns
   * synchronously (no skeleton) when every id is covered by the `selected` escape hatch,
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
    if (!this.#multiple) {
      if (value == null) {
        return undefined;
      }
      const resolved = this.#resolveMany([value], opts);
      return this.#isPromise<SelectItem[]>(resolved)
        ? this.#firstOf(resolved)
        : resolved[0]!;
    }
    const values = this.#dedupeValues(makeArray(value) as SelectItemId[]);
    // Empty multi → undefined so the trigger shows its placeholder (not an empty list).
    if (values.length === 0) {
      return undefined;
    }
    return this.#resolveMany(values, opts);
  }

  /**
   * The item to display for a single value without awaiting — including the `__unresolved`
   * fallback once an attempt has failed, so a trigger can tell "failed" (render the
   * fallback) from "still resolving" (`undefined`, render nothing).
   *
   * @param value - The single value; an array or `null` yields `undefined`.
   */
  resolveSingleSync(value: SelectValue): SelectItem | undefined {
    if (value == null || Array.isArray(value)) {
      return undefined;
    }
    return this.#resolveOneSync(value);
  }

  // Narrows a resolved batch back to the single arity. `#resolveMany` always yields at least
  // one item per requested id, so index 0 is present.
  async #firstOf(items: Promise<SelectItem[]>): Promise<SelectItem> {
    return (await items)[0]!;
  }

  /**
   * Ordered items for `values`: the sync ladder for what is already known, one batch call
   * for the rest, and an `__unresolved` fallback for whatever still doesn't resolve. Order
   * follows the bound ids, not the response. Never rejects.
   */
  #resolveMany(
    values: SelectItemId[],
    opts: SelectLoadOptions
  ): SelectItem[] | Promise<SelectItem[]> {
    const synced = values.map((v) => this.#resolveOneSync(v));
    if (synced.every((item) => item != null)) {
      return synced as SelectItem[];
    }
    const uncached = values.filter((_v, index) => synced[index] == null);
    const batch = this.#resolveBatch(uncached, opts);
    if (this.#isPromise(batch)) {
      return batch.then((resolved) => {
        const items = this.#assemble(values, synced, resolved);
        this.#cacheOutcome(values, items);
        return items;
      });
    }
    const items = this.#assemble(values, synced, batch);
    // A synchronous resolve runs *during* render, and this render already read the tracked
    // cache via `#resolveOneSync`. Preserve the result in an untracked map so the desktop
    // input can read its label later in this render without dirtying the consumed tag.
    this.#rememberSynchronousOutcomes(values, synced, items);
    return items;
  }

  #rememberSynchronousOutcomes(
    values: SelectItemId[],
    synced: Array<SelectItem | undefined>,
    items: SelectItem[]
  ): void {
    values.forEach((value, index) => {
      const key = this.#valueKey(value);
      const item = items[index];
      if (synced[index] == null && key != null && item) {
        this.#synchronousOutcomes.set(key, item);
      }
    });
  }

  /**
   * Records the outcome of an async resolve: real items, so later reads hit the cache
   * instead of refetching, and `__unresolved` fallbacks, so a trigger can tell "resolved and
   * failed" (show the fallback) from "still resolving" (show nothing). A cached fallback
   * remains a sync hit, but ranks after real selected/cache/list items; `reload()` evicts it
   * when the caller explicitly retries.
   *
   * Only ever called from a promise continuation, i.e. a microtask after render, where
   * writing tracked state cannot dirty what the render already read.
   */
  #cacheOutcome(values: SelectItemId[], items: SelectItem[]): void {
    values.forEach((value, index) => {
      const item = items[index];
      if (item) {
        this.#cacheResolvedValue(value, item);
      }
    });
  }

  /**
   * Sets the filter term (re-runs the list search).
   */
  @bind
  setFilter(term: string): void {
    this.#state.filter = term ?? "";
  }

  /**
   * Activates an item: runs its `onSelect` callback if present (an action item that
   * never becomes a value and does not close the overlay), otherwise toggles it.
   */
  @bind
  activate(item: SelectItem): void {
    if (typeof item?.onSelect === "function") {
      item.onSelect(this, item);
      return;
    }
    this.toggle(item);
  }

  /**
   * Toggles an item: for multi, selects or deselects; for single, selects it.
   */
  @bind
  toggle(item: SelectItem): void {
    if (this.#multiple && this.isSelected(item)) {
      this.deselect(item);
    } else {
      this.select(item);
    }
  }

  /**
   * Selects an item: caches it for synchronous display, computes the next value, and
   * emits `onChange`. For single-select it also requests the overlay to close (when
   * `closeOnSelect`). Never mutates the value — the parent does, via `onChange`.
   */
  @bind
  select(item: SelectItem): void {
    if (this.isSelected(item)) {
      return;
    }
    this.#cacheResolved(item);
    if (this.#multiple) {
      this.#emitChange([...this.#valueArray, this.#itemValue(item)]);
    } else {
      this.#emitChange(this.#itemValue(item));
      if (this.#closeOnSelect) {
        this.#requestClose?.();
      }
    }
  }

  /**
   * Removes an item from the selection (emits the next value).
   */
  @bind
  deselect(item: SelectItem): void {
    if (!this.#multiple) {
      this.#emitChange(null);
      return;
    }
    const key = this.#valueKey(this.#itemValue(item));
    this.#emitChange(this.#valueArray.filter((v) => this.#valueKey(v) !== key));
  }

  /** Removes the last held value from a multi-select selection. */
  @bind
  deselectLast(): void {
    if (!this.#multiple) {
      return;
    }
    const values = this.#valueArray;
    if (values.length === 0) {
      return;
    }
    this.#emitChange(values.slice(0, -1));
  }

  /**
   * Clears the entire selection (emits an empty value).
   */
  @bind
  clear(): void {
    this.#emitChange(this.#multiple ? [] : null);
  }

  /**
   * Forces the list to re-fetch even when the filter is unchanged, and drops the fallbacks
   * left by failed value resolutions so they are attempted again. Successfully resolved
   * items stay cached — only the failures are worth retrying.
   */
  @bind
  reload(): void {
    for (const [key, item] of [...this.#resolvedCache.entries()]) {
      if (item.__unresolved) {
        this.#resolvedCache.delete(key);
      }
    }
    for (const [key, item] of this.#synchronousOutcomes) {
      if (item.__unresolved) {
        this.#synchronousOutcomes.delete(key);
      }
    }
    this.#state.nonce++;
  }

  /**
   * Asks the overlay to close (wired by the component). Used by action items and the
   * compat bridge's `selectKit.close()`.
   */
  @bind
  requestClose(): void {
    this.#requestClose?.();
  }

  /**
   * The current value coerced to its multi-select array form. Only meaningful when
   * `#multiple` (the single-select value is never read through here); it centralizes
   * the one place the union `value` is treated as an array so the multi-only call sites
   * stay narrowing-free.
   */
  get #valueArray(): readonly SelectItemId[] {
    return this.value as readonly SelectItemId[];
  }

  // Emits the next value plus the best-effort resolved item(s) for it. Controlled: the
  // engine never stores the value — the parent applies `nextValue` to `@value`.
  #emitChange(nextValue: SelectValue): void {
    const items = this.#itemsFor(nextValue);
    const payload = this.#multiple ? items : (items[0] ?? null);

    // The selection-side-effect extension point: the default behavior emits the
    // controlled `onChange`; registered `select-on-change` transformers wrap it (and
    // may run `next()` to proceed or skip it).
    applyBehaviorTransformer(
      "select-on-change",
      () => this.#onChange?.(nextValue, payload),
      { identifiers: this.#identifiers, value: nextValue, items: payload }
    );

    // Legacy `modifySelectKit(id).onChange` extensions (side effects only, run after
    // the value has changed — matching the old ordering).
    applyLegacySelectKitOnChange(this, nextValue, payload);
  }

  // Best-effort synchronous resolution of a value to its item(s), from the escape
  // hatch / cache / client list — never async (this feeds the `onChange` payload).
  #itemsFor(value: SelectValue): SelectItem[] {
    const values: SelectItemId[] =
      value == null
        ? []
        : this.#multiple
          ? (makeArray(value) as SelectItemId[])
          : [value];
    return values
      .map((v) => this.#resolveOneSync(v))
      .filter((item): item is SelectItem => item != null);
  }

  // The one normalized source: a server `load` (may return a promise or, for a
  // dual-mode picker, a synchronous array) or a client-side filter over `items`.
  #source(
    filter: string,
    opts: SelectLoadOptions
  ): SelectItem[] | Promise<SelectItem[]> {
    if (this.#load) {
      return this.#load(filter, opts);
    }
    return this.#filterLocal(filter);
  }

  #filterLocal(filter: string): SelectItem[] {
    const all = this.#localItems();
    if (!filter) {
      return all;
    }
    const term = filter.toLowerCase();
    return all.filter((item) => this.#matchesFilter(item, term));
  }

  // The full client-side item set (empty for a server source), used both for local
  // filtering and to resolve a value's display item without a fetch.
  #localItems(): SelectItem[] {
    if (this.#load) {
      return [];
    }
    return typeof this.#items === "function"
      ? (this.#items() ?? [])
      : (makeArray(this.#items) as SelectItem[]);
  }

  #matchesFilter(item: SelectItem, term: string): boolean {
    if (typeof this.#filterBy === "function") {
      return this.#filterBy(item, term);
    }
    const field = this.#filterBy ?? this.#labelField;
    return String(item?.[field] ?? "")
      .toLowerCase()
      .includes(term);
  }

  #shouldOfferCreate(items: SelectItem[]): boolean {
    const filter = this.#state.filter;
    if (!filter || !this.#createItem) {
      return false;
    }
    const allowed =
      typeof this.#allowCreate === "function"
        ? this.#allowCreate(filter, items)
        : !!this.#allowCreate;
    if (!allowed) {
      return false;
    }
    // Don't offer to create a value that already exists (by label or value).
    const term = filter.toLowerCase();
    return !items.some(
      (item) =>
        String(this.#itemLabel(item) ?? "").toLowerCase() === term ||
        String(this.#itemValue(item) ?? "").toLowerCase() === term
    );
  }

  /**
   * The item to show for a value: escape hatch → a real recorded outcome → client list →
   * the fallback left by an earlier failed attempt.
   *
   * An `__unresolved` fallback ranks LAST, so any real source that turns up later — an item
   * landing in the client list, a re-resolve — supersedes it instead of being masked by it.
   * But it is still a hit, deliberately: a resolve records its outcome, and a read that
   * missed would re-resolve, record again, invalidate the render that read it, and never
   * settle. "Failed" has to be a terminal answer; `reload` is what retries it.
   */
  #resolveOneSync(value: SelectItemId): SelectItem | undefined {
    const key = this.#valueKey(value);
    if (key == null) {
      return undefined;
    }
    const recorded = this.#recordedOutcomes(key);
    return (
      this.#matching(makeArray(this.#selected) as SelectItem[], key) ??
      recorded.find((item) => !item.__unresolved) ??
      this.#matching(this.#localItems(), key) ??
      recorded[0]
    );
  }

  /**
   * What past resolves recorded for a value, across both stores. Async resolves record into
   * the tracked cache — their landing has to re-render the trigger — while synchronous ones
   * record into the untracked map, because writing tracked state during render would
   * invalidate the very render doing the write. A value normally lands in one or the other;
   * both are read the same way, so neither store's ordering is load-bearing.
   */
  #recordedOutcomes(key: string): SelectItem[] {
    return [
      this.#resolvedCache.get(key),
      this.#synchronousOutcomes.get(key),
    ].filter((item) => item != null);
  }

  #matching(items: SelectItem[], key: string): SelectItem | undefined {
    return items.find((i) => this.#valueKey(this.#itemValue(i)) === key);
  }

  // Resolves ids to a key→item map, containing only what genuinely resolved. Never throws
  // and never rejects. One batch call via `resolveValues` when given; otherwise per-id via
  // `resolveValue` (fans out — only when no batch resolver is supplied).
  #resolveBatch(
    values: SelectItemId[],
    opts: SelectLoadOptions
  ): Map<string, SelectItem> | Promise<Map<string, SelectItem>> {
    if (this.#resolveValues) {
      const result = this.#attempt(() => this.#resolveValues!(values, opts));
      return this.#isPromise(result)
        ? result.then(
            (items) => this.#toResolvedMap(items),
            () => new Map<string, SelectItem>()
          )
        : this.#toResolvedMap(result);
    }
    const per = values.map((v) => {
      const result = this.#attempt(() => this.#resolveValue?.(v, opts));
      return this.#isPromise(result)
        ? result.then(
            (item) => [v, item] as const,
            () => [v, undefined] as const
          )
        : ([v, result] as const);
    });
    return per.some((r) => this.#isPromise(r))
      ? Promise.all(per).then((pairs) => this.#pairsToMap(pairs))
      : this.#pairsToMap(
          per as ReadonlyArray<readonly [SelectItemId, SelectItem | undefined]>
        );
  }

  // Runs a resolver, turning a synchronous throw into "nothing resolved" — the same shape a
  // rejection produces. Without this a sync resolver's exception escapes mid-render, which
  // the "never rejects, never blanks" contract promises it cannot.
  #attempt<T>(fn: () => T): T | undefined {
    try {
      return fn();
    } catch {
      return undefined;
    }
  }

  // Keys the batch response by each item's OWN id, so a resolver that answers with an item
  // whose id differs from the one requested leaves the requested id unresolved rather than
  // silently mis-pairing the two.
  #toResolvedMap(
    items: SelectItem[] | null | undefined
  ): Map<string, SelectItem> {
    return this.#pairsToMap(
      (makeArray(items) as SelectItem[]).map(
        (item) => [this.#itemValue(item), item] as const
      )
    );
  }

  #pairsToMap(
    pairs: ReadonlyArray<readonly [SelectItemId, SelectItem | undefined]>
  ): Map<string, SelectItem> {
    const map = new Map<string, SelectItem>();
    for (const [value, item] of pairs) {
      const key = this.#valueKey(value);
      if (key != null && item) {
        map.set(key, item);
      }
    }
    return map;
  }

  // Builds the ordered array from the sync hits and the batch results, filling any id that
  // still did not resolve with an `__unresolved` fallback. Order follows `values`, not the
  // response. Pure — caching the outcome is `#cacheOutcome`'s job, and only off-render.
  #assemble(
    values: SelectItemId[],
    synced: Array<SelectItem | undefined>,
    resolved: Map<string, SelectItem>
  ): SelectItem[] {
    return values.map((v, index) => {
      const key = this.#valueKey(v);
      return (
        synced[index] ??
        (key == null ? undefined : resolved.get(key)) ??
        this.#unresolvedItem(v)
      );
    });
  }

  // The fallback for a held id that could not be resolved. `createUnresolvedItem` names it
  // ("Topic #123"); the default shows the bare id. Either way the engine owns the
  // `__unresolved` marker, so a builder cannot hand back something that reads as resolved.
  #unresolvedItem(value: SelectItemId): SelectItem {
    const built = this.#createUnresolvedItem
      ? this.#attempt(() => this.#createUnresolvedItem!(value))
      : undefined;
    if (built) {
      const item = {
        ...built,
        [this.#valueField]: value,
        __unresolved: true,
      };
      this.#customUnresolvedItems.add(item);
      return item;
    }
    const item: SelectItem = { [this.#valueField]: value, __unresolved: true };
    // Show the value as the label so an unresolved row renders the id, not a blank — unless
    // the label field IS the value field, where it is already present (keeping the raw type).
    if (this.#labelField !== this.#valueField) {
      item[this.#labelField] = String(value ?? "");
    }
    return item;
  }

  #cacheResolved(item: SelectItem | null | undefined): void {
    if (item) {
      this.#cacheResolvedValue(this.#itemValue(item), item);
    }
  }

  #cacheResolvedValue(
    value: SelectItemId,
    item: SelectItem | null | undefined
  ): void {
    const key = this.#valueKey(value);
    if (key != null && item && this.#resolvedCache.get(key) !== item) {
      this.#resolvedCache.set(key, item);
    }
  }

  #normalize(item: SelectItem, index: number): SelectDescriptor {
    const value = this.#itemValue(item);
    return {
      // A value-less synthetic row (e.g. a null-id special) has no natural key; fall back to
      // its position, which is stable within the ordered special/create prefix.
      key: this.#valueKey(value) ?? `__row:${index}`,
      value,
      item,
      flags: {
        selected: this.isSelected(item),
        disabled: !!item.disabled,
        group: false,
        __create: !!item.__create,
        __unresolved: !!item.__unresolved,
      },
    };
  }

  #itemValue(item: SelectItem | null | undefined): SelectItemId {
    return item?.[this.#valueField];
  }

  // Two ids denote the same option iff their string forms match, so a bound "5" selects
  // item id 5 (and vice-versa). Nullish never matches an id.
  #valueKey(value: SelectItemId): string | null {
    return value == null ? null : String(value);
  }

  /** Removes duplicate normalized ids while preserving first-occurrence order. */
  #dedupeValues(values: SelectItemId[]): SelectItemId[] {
    const seen = new Set<string | null>();
    return values.filter((value) => {
      const key = this.#valueKey(value);
      if (seen.has(key)) {
        return false;
      }
      seen.add(key);
      return true;
    });
  }

  #itemLabel(item: SelectItem | null | undefined): unknown {
    return item?.[this.#labelField];
  }

  #snapshot(): SelectSnapshot {
    return Object.freeze({
      filter: this.#state.filter,
      value: this.value,
      hasValue: this.hasValue,
    });
  }

  #isPromise<T>(value: T | Promise<T>): value is Promise<T> {
    return (
      value != null && typeof (value as { then?: unknown }).then === "function"
    );
  }
}
