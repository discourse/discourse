import { tracked } from "@glimmer/tracking";
import { makeArray } from "discourse/lib/helpers";
import type {
  SelectEngineOptions,
  SelectItem,
  SelectLoadOptions,
  SelectLoadResponse,
  SelectLoadResult,
} from "discourse/ui-kit/select/select-engine";
import type SelectOptionsView from "./select-options";

export const MAX_RENDERED = 200;

/**
 * The full client-side item set (empty for a server source), used both for local
 * filtering and to resolve a value's display item without a fetch.
 */
export function localItems(options: SelectOptionsView): SelectItem[] {
  if (options.isAsync) {
    return [];
  }
  // `makeArray` normalizes whatever the source yields — a thunk that returns null, or a
  // non-array value — into a real array, so downstream array reads never see a non-array.
  const resolved =
    typeof options.items === "function" ? options.items() : options.items;
  return makeArray(resolved) as SelectItem[];
}

/** The client list after `filterBy` — the one filter pass a `LocalSource` answers with. */
export function filterLocal(
  options: SelectOptionsView,
  filter: string
): SelectItem[] {
  const all = localItems(options);
  if (!filter) {
    return all;
  }
  const term = filter.toLowerCase();
  return all.filter((item) => matchesFilter(options, item, term));
}

function matchesFilter(
  options: SelectOptionsView,
  item: SelectItem,
  term: string
): boolean {
  if (typeof options.filterBy === "function") {
    return options.filterBy(item, term);
  }
  const field = options.filterBy ?? options.labelField;
  return String(item?.[field] ?? "")
    .toLowerCase()
    .includes(term);
}

/**
 * Private, fixed-shape reactive state for a {@link SelectEngine}. Declaring the fields
 * on a small class (rather than a `trackedObject`) enforces the shape and keeps
 * standard `@tracked` semantics; the instance is held in a `#`-private field, so it is
 * unreachable from outside the engine. Note there is deliberately no `selection` here:
 * the value is controlled by the parent (see {@link SelectEngine}).
 */
export class SelectState {
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

export interface SelectSource {
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
}

export class LocalSource implements SelectSource {
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
}

export class PagedSource implements SelectSource {
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
    // `serverCompletedKey` is deliberately left pointing at the previous load: that is what makes
    // the new one read as pending until its first page lands.
    //
    // `serverSettledKey` must go, because it claims the accumulator holds a complete successful
    // answer for that key — which the line below makes false. Keeping it only looks harmless while
    // the next key differs; coming BACK to a filter that already settled (the ordinary typeahead
    // close, which restores the empty query) matches it again over discarded rows, and the reuse
    // short-circuit then answers `[]` synchronously with nothing left to re-ask.
    this.#state.serverSettledKey = null;
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

  /**
   * Identifies the load the accumulator is (or should be) holding. Any change to it means
   * the accumulated pages no longer answer the current question.
   */
  get #loadKey(): string {
    const { filter, nonce, reveal } = this.#state;
    return JSON.stringify([filter, nonce, reveal]);
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
    // An abandoned request must not keep answering for the one that replaces it. The consumer
    // aborts on teardown, so a panel closed mid-flight and reopened before the abort settles
    // would otherwise hit the in-flight short-circuit above and be handed the accumulator —
    // empty, on a first page — as a synchronous answer, leaving the query reading "no results"
    // with nothing left to re-ask. Releasing the handle is enough: the generation deliberately
    // does NOT move, so the settle below still stamps `serverCompletedKey` (see its comment).
    opts.signal?.addEventListener(
      "abort",
      () => {
        if (this.#serverRequest === request) {
          this.#serverRequest = undefined;
        }
      },
      { once: true }
    );
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
