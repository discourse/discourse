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

const MAX_RENDERED = 200;

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
    /** Reserved for group headers; always false today. */
    group: boolean;
    /** Marks the synthetic create-on-the-fly row. */
    __create: boolean;
    /** True for an unresolved held value; false on list rows. */
    __unresolved: boolean;
  };
  /**
   * 1-based position in the whole result set, independent of how many rows are mounted.
   * Stamped by {@link SelectEngine#buildItems} only; the trigger/chip path leaves it
   * undefined.
   */
  posInSet?: number;
  /**
   * Size of the whole result set, or `-1` when it cannot be reported or derived — which now
   * means a source mid-paging under `hasMore: true` with no `total`, or one stopped by the
   * barren-page brake.
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

/** Constructor options for a {@link SelectEngine}. */
export interface SelectEngineOptions {
  /** Multi-select when true (drives value shape, chips, and close-on-select). */
  multiple?: boolean;

  /**
   * `() => value` — reads the controlled value live (single: an id or `null`; multi: an
   * id array). Defaults to always-`null`.
   */
  getValue?: () => SelectValue;

  /**
   * Live readers for the reactive inputs. When supplied they are read on every access, so a
   * runtime change to the underlying `@arg` propagates (the plain static option beside each is
   * a construction-time snapshot for direct, non-reactive consumers). A component wires these
   * to its live args; the engine re-applies each default on read. See {@link getValue}.
   */
  getMultiple?: () => boolean | undefined;
  getMinChars?: () => number | undefined;
  getSelected?: () => SelectItem | SelectItem[] | undefined;
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

  /** Advances the paginated source's request context. */
  @tracked reveal = 0;

  /** The server's true result count when it reports one. */
  @tracked serverTotal?: number;

  /** Whether the paginated source has no page left to reveal. */
  @tracked serverExhausted = false;

  /**
   * Whether the source asserted that what it returned is the whole set — by declaring no
   * more pages, or by staying silent, which the contract treats as the same claim. Kept
   * distinct from {@link serverExhausted} because paging can also stop for reasons that say
   * nothing about size (the barren-page brake, a reported ceiling), and those must never
   * become a factual set size for assistive technology.
   */
  @tracked serverComplete = false;

  /**
   * Whether a row not already held was discarded at the render cap. Merely filling the cap
   * exactly does not make the result truncated.
   */
  @tracked serverTruncated = false;

  /**
   * How many deduped rows the accumulator holds. Mirrors the untracked buffer's length so
   * the gating getters depend on real tracked state rather than reading the buffer.
   */
  @tracked serverLoadedCount = 0;

  /**
   * The load context whose page **succeeded**, or `null` before the first one. Gates
   * reusing the accumulator, so a failed load never passes its empty buffer off as a
   * result. Written only after an await, never during render.
   */
  @tracked serverSettledKey: string | null = null;

  /**
   * The load context that last **finished**, successfully or not. Deliberately distinct
   * from {@link serverSettledKey}: a rejection has to stop reading as in-flight (or
   * `aria-busy` pins on and reveal dies), but must not imply there is data to show.
   */
  @tracked serverCompletedKey: string | null = null;

  /**
   * Bumped by {@link SelectEngine#reload} to force the list to re-fetch even when the
   * filter is unchanged (e.g. an "AI suggestions" flow).
   */
  @tracked nonce = 0;
}

interface SelectSource {
  rows(opts: SelectLoadOptions): SelectItem[] | Promise<SelectItem[]>;
  total(): number | undefined;
  canRevealMore(): boolean;
  atCapWithMore(): boolean;
  pending(): boolean;
  revealPending(): boolean;
  revealMore(): boolean;
  knownRows(): SelectItem[];
  reset(): void;
  revealToken(): number;
  reactiveItems(): readonly SelectItem[];
  knownComplete(): boolean;
}

class LocalSource implements SelectSource {
  #filtered: () => readonly SelectItem[];
  #all: () => SelectItem[];

  constructor(opts: {
    filtered: () => readonly SelectItem[];
    all: () => SelectItem[];
  }) {
    this.#filtered = opts.filtered;
    this.#all = opts.all;
  }

  rows(): SelectItem[] {
    return this.#filtered() as SelectItem[];
  }

  total(): number {
    return this.#filtered().length;
  }

  canRevealMore(): boolean {
    return false;
  }

  atCapWithMore(): boolean {
    return false;
  }

  pending(): boolean {
    return false;
  }

  revealPending(): boolean {
    return false;
  }

  revealMore(): boolean {
    return false;
  }

  knownRows(): SelectItem[] {
    return this.#all();
  }

  reset(): void {}

  revealToken(): number {
    return 0;
  }

  reactiveItems(): readonly SelectItem[] {
    return this.#all();
  }

  knownComplete(): boolean {
    return true;
  }
}

class PagedSource implements SelectSource {
  #load: NonNullable<SelectEngineOptions["load"]>;
  #state: SelectState;
  #keyOf: (item: SelectItem) => string | null;
  #serverItems: SelectItem[] = [];
  #serverOffset = 0;
  #serverPageSize?: number;
  #serverGeneration = 0;
  #serverBarrenPages = 0;
  #serverRequest?: Promise<SelectLoadResult>;

  constructor(opts: {
    load: NonNullable<SelectEngineOptions["load"]>;
    state: SelectState;
    keyOf: (item: SelectItem) => string | null;
  }) {
    this.#load = opts.load;
    this.#state = opts.state;
    this.#keyOf = opts.keyOf;
  }

  /**
   * Identifies the load the accumulator is (or should be) holding. Any change to it means
   * the accumulated pages no longer answer the current question.
   */
  get #loadKey(): string {
    const { filter, nonce, reveal } = this.#state;
    return JSON.stringify([filter, nonce, reveal]);
  }

  rows(opts: SelectLoadOptions): SelectItem[] | Promise<SelectItem[]> {
    return this.#loadServerItems(this.#state.filter, opts);
  }

  total(): number | undefined {
    const { serverComplete, serverLoadedCount, serverTotal, serverTruncated } =
      this.#state;
    return serverComplete && !serverTruncated ? serverLoadedCount : serverTotal;
  }

  canRevealMore(): boolean {
    return (
      !this.pending() &&
      !this.#state.serverExhausted &&
      this.#state.serverLoadedCount < MAX_RENDERED
    );
  }

  atCapWithMore(): boolean {
    const { serverLoadedCount, serverExhausted, serverTotal, serverTruncated } =
      this.#state;
    return (
      serverTruncated ||
      (serverLoadedCount >= MAX_RENDERED &&
        !serverExhausted &&
        (serverTotal == null || serverLoadedCount < serverTotal))
    );
  }

  pending(): boolean {
    const completed = this.#state.serverCompletedKey;
    return completed != null && completed !== this.#loadKey;
  }

  revealPending(): boolean {
    const completed = this.#state.serverCompletedKey;
    if (!this.pending() || completed == null) {
      return false;
    }
    // The key is `[filter, nonce, reveal]`: same query, different cursor means a reveal.
    const [filter, nonce] = JSON.parse(completed) as [string, number, number];
    return filter === this.#state.filter && nonce === this.#state.nonce;
  }

  revealMore(): boolean {
    // `#serverRequest` is the authoritative in-flight check and is read directly because
    // this runs from an action, never during render. `canRevealMore` is its reactive
    // counterpart for gating the sentinel.
    if (this.#serverRequest || !this.canRevealMore()) {
      return false;
    }

    this.#state.reveal++;
    return true;
  }

  knownRows(): SelectItem[] {
    return this.#serverItems;
  }

  reset(): void {
    this.#state.reveal = 0;
    this.#state.serverTotal = undefined;
    this.#state.serverExhausted = false;
    this.#state.serverComplete = false;
    this.#state.serverTruncated = false;
    this.#state.serverLoadedCount = 0;
    // Neither key is cleared: leaving them pointing at the previous load is what makes the
    // new one read as pending until its first page lands, and what stops the stale
    // accumulator being reused for it.
    this.#serverItems = [];
    this.#serverOffset = 0;
    this.#serverPageSize = undefined;
    this.#serverBarrenPages = 0;
    this.#serverGeneration++;
    this.#serverRequest = undefined;
  }

  revealToken(): number {
    return this.#state.reveal;
  }

  reactiveItems(): readonly SelectItem[] {
    return [];
  }

  knownComplete(): boolean {
    return this.#state.serverComplete && !this.#state.serverTruncated;
  }

  #loadServerItems(
    filter: string,
    opts: SelectLoadOptions
  ): SelectItem[] | Promise<SelectItem[]> {
    if (
      this.#serverRequest ||
      this.#state.serverExhausted ||
      this.#serverItems.length >= MAX_RENDERED ||
      this.#state.serverSettledKey === this.#loadKey
    ) {
      return this.#serverItems.slice(0, MAX_RENDERED);
    }

    const generation = this.#serverGeneration;
    const key = this.#loadKey;
    const request = Promise.resolve(
      this.#load(filter, {
        ...opts,
        offset: this.#serverOffset,
        limit: this.#serverPageSize,
      })
    );
    this.#serverRequest = request;
    return this.#settleServerPage(request, key, generation, opts.signal);
  }

  async #settleServerPage(
    request: Promise<SelectLoadResult>,
    key: string,
    generation: number,
    signal?: AbortSignal
  ): Promise<SelectItem[]> {
    let settled = false;
    try {
      const response = await request;
      if (signal?.aborted || generation !== this.#serverGeneration) {
        return this.#serverItems.slice(0, MAX_RENDERED);
      }

      const { items, total, hasMore } = this.#unwrapLoadResult(response);
      const knownTotal = total ?? this.#state.serverTotal;
      const before = this.#serverItems.length;
      this.#serverOffset += items.length;
      this.#serverPageSize ??= items.length || undefined;
      const truncated = this.#appendServerItems(items);
      const added = this.#serverItems.length - before;

      // Reachable only under `hasMore: true`, since silence now ends paging on its own. It is
      // the residual brake on a source that claims more forever: tolerating one barren page
      // still supports overlapping pages, and the second stops it.
      this.#serverBarrenPages = added === 0 ? this.#serverBarrenPages + 1 : 0;

      // Against *deduped* rows: the raw cursor outruns them whenever pages overlap, and
      // comparing it here would strand the tail.
      const ceilingReached =
        knownTotal != null && this.#serverItems.length >= knownTotal;

      // Silence means the set is complete, so only an affirmative signal buys another fetch.
      // An explicit `hasMore: false` is terminal whatever `total` says: a source may report 99
      // matches while permitting only 5, and those 5 are all the user can ever navigate to.
      const moreDeclared =
        hasMore === true ||
        (hasMore == null &&
          knownTotal != null &&
          this.#serverItems.length < knownTotal);

      this.#state.serverTotal = knownTotal;
      // Silence is an assertion of completeness, so it may size the set. The extra guard is
      // narrower than it looks: it only catches a source that replayed pages and *then*
      // declared completeness, which has already proven it cannot be trusted to count.
      this.#state.serverComplete = !moreDeclared && this.#serverBarrenPages < 2;
      // Assigned rather than accumulated: filling the cap stops the next fetch outright, so
      // no page can follow a truncating one within a query.
      this.#state.serverTruncated = truncated;
      this.#state.serverExhausted =
        !moreDeclared || ceilingReached || this.#serverBarrenPages >= 2;
      this.#state.serverLoadedCount = this.#serverItems.length;
      settled = true;

      return this.#serverItems.slice(0, MAX_RENDERED);
    } finally {
      if (this.#serverRequest === request) {
        this.#serverRequest = undefined;
      }
      if (generation === this.#serverGeneration) {
        // Completion covers rejection AND abort: this request is over either way. Skipping
        // it on abort left the key behind the live one forever, pinning `aria-busy` on and
        // making `canRevealMore` permanently false — the list could never be revealed
        // again. The cost is that a same-key retry reads as settled while it is genuinely
        // in flight, which is a brief missing busy signal rather than a dead control.
        this.#state.serverCompletedKey = key;
        if (settled) {
          // Only a success may authorise reusing the accumulator. Marking a failed key
          // settled would make the next `loadItems` hand back the empty buffer instead of
          // the rejection, replacing the error UI (and its retry) with an empty list.
          this.#state.serverSettledKey = key;
        }
      }
    }
  }

  #appendServerItems(items: SelectItem[]): boolean {
    const keys = new Set(
      this.#serverItems
        .map((item) => this.#keyOf(item))
        .filter((key): key is string => key != null)
    );
    for (const item of items) {
      const key = this.#keyOf(item);
      if (key != null && keys.has(key)) {
        continue;
      }

      if (this.#serverItems.length >= MAX_RENDERED) {
        // The accumulator can no longer grow and `keys` is never read again, so one
        // discarded row settles the question. Returning here also keeps the scan bounded by
        // the cap rather than by the page, which a pre-pagination source sizes at the whole
        // dataset.
        return true;
      }

      this.#serverItems.push(item);
      if (key != null) {
        keys.add(key);
      }
    }

    return false;
  }

  #unwrapLoadResult(response: SelectLoadResult): SelectLoadResponse {
    return Array.isArray(response) ? { items: response } : response;
  }
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

  // Fires the `@items`+`@load` misconfiguration warning at most once per engine.
  #dualSourceWarned = false;

  #readMultiple: () => boolean | undefined;
  #identifiers: string[];
  #readMinChars: () => number | undefined;
  #valueField: string;
  #labelField: string;
  #filterBy?: string | ((item: SelectItem, term: string) => boolean);
  #items?: SelectItem[] | (() => SelectItem[] | null | undefined);
  #load?: (
    filter: string,
    opts: SelectLoadOptions
  ) => SelectLoadResult | Promise<SelectLoadResult>;
  #readSelected: () => SelectItem | SelectItem[] | undefined;
  #resolveValue?: (
    value: SelectItemId,
    opts: SelectLoadOptions
  ) => SelectItem | Promise<SelectItem | undefined> | undefined;
  #resolveValues?: (
    values: SelectItemId[],
    opts: SelectLoadOptions
  ) => SelectItem[] | Promise<SelectItem[]>;
  #readAllowCreate: () =>
    | boolean
    | ((filter: string, items: SelectItem[]) => boolean)
    | undefined;
  #createItem?: (filter: string) => SelectItem;
  #createUnresolvedItem?: (value: SelectItemId) => SelectItem;
  #specialItems?: (snapshot: SelectSnapshot) => SelectItem[];
  #readCloseOnSelect: boolean | undefined;
  #onChange?: (
    nextValue: SelectValue,
    item: SelectItem | SelectItem[] | null
  ) => void;
  #requestClose?: () => void;
  #readValue: () => SelectValue;
  #isAsync: boolean;
  #legacy: SelectLegacyContext | null;
  #source!: SelectSource;

  /**
   * @param opts.multiple - Multi-select when true (drives value shape, chips, and
   *   close-on-select).
   * @param opts.getValue - `() => value` — reads the controlled value live (single: an
   *   id or `null`; multi: an id array). Defaults to always-`null`.
   * @param opts.identifiers - Keys plugin `select-content` transformers match on.
   * @param opts.items - A static array (or `() => array`) of items — the client-only
   *   source. Provide this or `load`, not both.
   * @param opts.load - `(filter, { signal, offset, limit }) => items | { items, total?,
   *   hasMore? }`, synchronously or as a promise. Pagination starts without a limit so the
   *   source defines its page size. Declaring neither `total` nor `hasMore` means the
   *   response is the complete set.
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
    this.#readMultiple = opts.getMultiple ?? (() => opts.multiple);
    this.#identifiers = makeArray(opts.identifiers) as string[];
    this.#readMinChars = opts.getMinChars ?? (() => opts.minChars);
    this.#valueField = opts.valueField ?? "id";
    this.#labelField = opts.labelField ?? "name";
    this.#filterBy = opts.filterBy;
    this.#items = opts.items;
    this.#load = opts.load;
    this.#readSelected = opts.getSelected ?? (() => opts.selected);
    this.#resolveValue = opts.resolveValue;
    this.#resolveValues = opts.resolveValues;
    this.#readAllowCreate = opts.getAllowCreate ?? (() => opts.allowCreate);
    this.#createItem = opts.createItem;
    this.#createUnresolvedItem = opts.createUnresolvedItem;
    this.#specialItems = opts.specialItems;
    // Kept raw (not defaulted here): `#closeOnSelect` re-derives `!multiple` live, so a
    // runtime `multiple` flip flips the default close behavior with it.
    this.#readCloseOnSelect = opts.closeOnSelect;
    this.#onChange = opts.onChange;
    this.#requestClose = opts.requestClose;
    this.#legacy = opts.legacy ?? null;
    // The controlled value is read live via this thunk, so the engine reflects the
    // parent's `@value` without storing any selection of its own.
    this.#readValue = opts.getValue ?? (() => null);
    this.#isAsync = typeof opts.load === "function";
    this.#source = this.#load
      ? new PagedSource({
          load: this.#load,
          state: this.#state,
          keyOf: (item) => this.#valueKey(this.#itemValue(item)),
        })
      : new LocalSource({
          filtered: () => this.filteredItems,
          all: () => this.#localItems(),
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

  /** The minimum filter length before the list searches (`0` = no minimum). */
  get minChars(): number {
    return this.#minChars;
  }

  /**
   * Whether the current query is shorter than {@link minChars} — the "keep typing" state, in
   * which the list should not search. Reads the filter reactively, so the component's gate
   * re-evaluates as the user types. An empty query counts as below the threshold: with a
   * minimum set, opening should prompt for input, not load (and then hide) the whole list.
   */
  get belowMinChars(): boolean {
    return this.#minChars > 0 && this.#state.filter.length < this.#minChars;
  }

  /** How many more characters are needed to reach {@link minChars} (reactive). */
  get remainingMinChars(): number {
    return Math.max(0, this.#minChars - this.#state.filter.length);
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
    // Copied AND frozen. With no filter `#filterLocal` passes the consumer's own array
    // straight through, and `readonly` is erased at runtime — but copying alone is not
    // enough either, because `@cached` hands the same array to every reader in the render,
    // so mutating it would corrupt what the engine itself reads next. Matches `buildItems`,
    // which also yields a frozen projection.
    return Object.freeze([...this.#filterLocal(this.#state.filter)]);
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

    const sourceCount = items.length;
    let createCount = 0;
    if (this.#shouldOfferCreate(items)) {
      // `#shouldOfferCreate` already guaranteed a `#createItem` is present.
      items = [...items, this.#createItem!(this.#state.filter)];
      createCount = 1;
    }

    const special = this.#specialItems?.(this.#snapshot()) ?? [];
    const specialItems = makeArray(special) as SelectItem[];
    const finalItems = [...specialItems, ...items];

    // Normalize as the final step: everything above operates on raw items (so the
    // transformer / bridge / onSelect pipeline is unchanged); only the render array is wrapped.
    return this.#describeList(
      finalItems,
      specialItems.length,
      sourceCount,
      createCount
    );
  }

  /**
   * Normalizes the list rows — specials, then source rows, then create — and stamps each with
   * its position in the whole result set. Positions come from the engine's own totals rather
   * than the DOM index, so they stay correct while only a window is mounted.
   */
  #describeList(
    items: SelectItem[],
    specialCount: number,
    sourceCount: number,
    createCount: number
  ): readonly SelectDescriptor[] {
    const total = this.total;
    const knownComplete = this.#source.knownComplete();
    // A transformer or the legacy bridge can add rows absent from a reported or derived
    // total, so trusting that total blindly could emit a position past the set.
    const sourceTotal =
      total == null || !knownComplete ? null : Math.max(total, sourceCount);
    const setSize =
      sourceTotal == null ? -1 : specialCount + sourceTotal + createCount;

    // Loaded source rows are a prefix, so positions are known even while the set size is not.
    // `-1` with real positions is the unknown-size encoding ARIA describes.
    const lastSourceIndex = specialCount + sourceCount;

    return Object.freeze(
      items.map((item, index) => ({
        ...this.#normalize(item, index),
        setSize,
        posInSet:
          index < lastSourceIndex
            ? index + 1
            : // The create row closes the set, wherever the window ends — but only a known
              // set has a last slot to close.
              sourceTotal == null
              ? undefined
              : setSize,
      }))
    );
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
      // Re-picking the current value is a confirmation, not a change: emit nothing, but still
      // close. Since the list restores the cursor to the selected option, this is the first
      // keystroke after opening, and leaving it inert would read as a broken control.
      if (!this.#multiple && this.#closeOnSelect) {
        this.#requestClose?.();
      }
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
   * Resets the source and forces a re-fetch even when the filter is unchanged. Also
   * drops failed value-resolution fallbacks so they are attempted again; successful items
   * stay cached.
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
    this.#source.reset();
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
   * Live-resolved reactive inputs. Each reads its thunk on every access (so a runtime change
   * to the wired `@arg` propagates) and re-applies the default the constructor used to bake in.
   * Read-site code uses `this.#multiple` etc. unchanged — these getters stand in for the former
   * plain fields.
   */
  get #multiple(): boolean {
    return this.#readMultiple() ?? false;
  }

  get #minChars(): number {
    return this.#readMinChars() ?? 0;
  }

  get #selected(): SelectItem | SelectItem[] | undefined {
    return this.#readSelected();
  }

  get #allowCreate():
    | boolean
    | ((filter: string, items: SelectItem[]) => boolean)
    | undefined {
    return this.#readAllowCreate();
  }

  // Defaults to `!multiple`, re-derived live so a runtime `multiple` flip flips it too.
  get #closeOnSelect(): boolean {
    return this.#readCloseOnSelect ?? !this.#multiple;
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
    if (this.#isAsync) {
      return [];
    }
    // `makeArray` normalizes whatever the source yields — a thunk that returns null, or a
    // non-array value — into a real array, so downstream array reads never see a non-array.
    const resolved =
      typeof this.#items === "function" ? this.#items() : this.#items;
    return makeArray(resolved) as SelectItem[];
  }

  // `items` and `load` are mutually exclusive; the construction-time source kind wins.
  // Warns once when both are supplied — checked here rather than only in the constructor
  // because a live `items` source can turn non-empty after construction.
  #assertSingleSource(): void {
    if (this.#dualSourceWarned || !this.#isAsync) {
      return;
    }
    const local =
      typeof this.#items === "function" ? this.#items() : this.#items;
    if (local != null && (makeArray(local) as SelectItem[]).length > 0) {
      this.#dualSourceWarned = true;
      // eslint-disable-next-line no-console
      console.warn(
        "DSelect: `@items` and `@load` are mutually exclusive; `@load` takes precedence and `@items` is ignored."
      );
    }
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
      this.#matching(this.#knownRows(), key) ??
      recorded[0]
    );
  }

  // The rows already in hand for the current source, whichever kind it is. A paginated
  // source returns its untracked accumulator; without this rung it would refetch a value
  // whose row is already on screen. Read untracked on purpose — this runs during render,
  // and the fetch path already covers the case where the row has not landed yet.
  #knownRows(): SelectItem[] {
    return this.#source.knownRows();
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
