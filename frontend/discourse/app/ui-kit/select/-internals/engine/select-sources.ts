import { tracked } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import type {
  SelectEngineInit,
  SelectLoadRequest,
  SelectLoadResult,
  SelectRecord,
} from "discourse/ui-kit/select/select-engine";
import type SelectArgsView from "./select-args.ts";
import { assertOptionsList } from "./select-args.ts";
import type { SelectOption, SelectOptionLike } from "./select-option.ts";
import type { UpdateRecord } from "./selection-updates.ts";

/** A page as the source holds it: options, with the paging facts the loader declared. */
interface SelectLoadedPage {
  options: readonly SelectOption[];
  total?: number;
  hasMore?: boolean;
  cursor?: unknown;
}

/**
 * The full client-side option set (empty for a server source), used both for local
 * filtering and to resolve a value's record without a fetch.
 */
export function localOptions(args: SelectArgsView): readonly SelectOption[] {
  if (args.isAsync) {
    return [];
  }
  const resolved =
    typeof args.options === "function"
      ? args.options(args.config)
      : args.options;
  assertOptionsList(resolved);
  return args.wrapEntries(resolved);
}

/** The client list after `filterBy` — the one filter pass a `LocalSource` answers with. */
export function filterLocal(
  args: SelectArgsView,
  filter: string
): readonly SelectOption[] {
  const all = localOptions(args);
  if (!filter) {
    return all;
  }
  const term = filter.toLowerCase();
  return all.filter((option) => matchesFilter(args, option.record, term));
}

function matchesFilter(
  args: SelectArgsView,
  record: SelectRecord,
  term: string
): boolean {
  if (typeof args.filterBy === "function") {
    return args.filterBy(record, term, args.config);
  }
  const field = args.filterBy ?? args.labelField;
  return String(record?.[field] ?? "")
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
  /** Mirrors only asynchronous updates so synchronous work never invalidates a render. */
  @tracked update: UpdateRecord | null = null;

  /** The current filter/search term. */
  @tracked filter = "";

  /** Advances the paginated source's request context. */
  @tracked reveal = 0;

  /** The server's true result count when it reports one. */
  @tracked serverTotal?: number;

  /** Whether the paginated source has no page left to reveal. */
  @tracked serverExhausted = false;

  /** Whether consecutive reveals stopped adding visible options for this query. */
  @tracked visiblyExhausted = false;

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
  /** Whether the latest answer arrived without a promise, so a filter change need not wait. */
  answersSynchronously(): boolean;
  /** Records a rendered source's transformed option count, built from `input` raw rows. */
  noteVisible(visible: number, input: number): void;
  rows(opts: SelectLoadRequest): SelectOption[] | Promise<SelectOption[]>;
  total(): number | undefined;
  canRevealMore(): boolean;
  /** Whether later rows may still arrive for this query, whether or not a page is in flight. */
  mayGrow(): boolean;
  atCapWithMore(): boolean;
  pending(): boolean;
  awaitingFirstPage(): boolean;
  revealPending(): boolean;
  queryPending(): boolean;
  revealMore(): boolean;
  /** The options the source holds now, for resolving values and parsing pastes. */
  knownOptions(): readonly SelectOption[];
  /** The records behind {@link knownOptions}. */
  knownRecords(): SelectRecord[];
  reset(): void;
  revealToken(): number;
  reactiveOptions(): readonly SelectOption[];
}

export class LocalSource implements SelectSource {
  #filtered: () => readonly SelectOption[];
  #all: () => readonly SelectOption[];

  constructor(opts: {
    filtered: () => readonly SelectOption[];
    all: () => readonly SelectOption[];
  }) {
    this.#filtered = opts.filtered;
    this.#all = opts.all;
  }

  rows(): SelectOption[] {
    return this.#filtered() as SelectOption[];
  }

  answersSynchronously(): boolean {
    return true;
  }

  /** Client sources have no paging progress to measure. */
  noteVisible(): void {}

  total(): number {
    return this.#filtered().length;
  }

  canRevealMore(): boolean {
    return false;
  }

  mayGrow(): boolean {
    return false;
  }

  atCapWithMore(): boolean {
    return false;
  }

  pending(): boolean {
    return false;
  }

  awaitingFirstPage(): boolean {
    return false;
  }

  revealPending(): boolean {
    return false;
  }

  queryPending(): boolean {
    return false;
  }

  revealMore(): boolean {
    return false;
  }

  knownOptions(): readonly SelectOption[] {
    return this.#all();
  }

  knownRecords(): SelectRecord[] {
    return this.#all().map((option) => option.record);
  }

  reset(): void {}

  revealToken(): number {
    return 0;
  }

  reactiveOptions(): readonly SelectOption[] {
    return this.#all();
  }
}

export class PagedSource implements SelectSource {
  /** The query's loader, reused by its reveals and retries until the query resets. */
  #queryLoad?: NonNullable<SelectEngineInit["load"]>;

  /** Resolves the source for the first request of each query. */
  #resolveLoad: (filter: string) => NonNullable<SelectEngineInit["load"]>;
  #state: SelectState;
  #keyOf: (option: SelectOption) => string | null;
  #wrap: (entries: readonly SelectOptionLike[]) => readonly SelectOption[];
  #getMaxLoaded: () => number | undefined;
  #serverOptions: SelectOption[] = [];
  #serverKeys = new Set<string>();
  #serverOffset = 0;
  #serverCursor?: unknown;
  #serverPage = 1;
  #serverPageSize?: number;
  #serverGeneration = 0;
  #serverBarrenPages = 0;
  #serverRequest?: Promise<SelectLoadResult>;

  /**
   * The request this generation started last. An abort releases `#serverRequest` but not this,
   * so only the latest request, abandoned or not, may mark the load complete.
   */
  #latestServerRequest?: Promise<SelectLoadResult>;

  /** Whether the loader's latest call returned its answer rather than a promise. */
  #answeredSynchronously = false;

  /** Consecutive measured reveals that added no visible options. */
  #barrenReveals = 0;

  /** Option count from the latest settled build. */
  #visible?: number;

  /** Option count when the previous reveal began, if it had been built. */
  #visibleAtReveal?: number;

  /** Whether settled rows have been built since the previous reveal. */
  #visibleMeasured = false;

  constructor(opts: {
    /** Resolves a query's loader outside render, when its first request starts. */
    resolveLoad: (filter: string) => NonNullable<SelectEngineInit["load"]>;
    state: SelectState;
    keyOf: (option: SelectOption) => string | null;
    /** Wraps a page's entries as options when it arrives. */
    wrap: (entries: readonly SelectOptionLike[]) => readonly SelectOption[];
    /** Reads the optional server row ceiling. */
    getMaxLoaded?: () => number | undefined;
  }) {
    this.#resolveLoad = opts.resolveLoad;
    this.#state = opts.state;
    this.#keyOf = opts.keyOf;
    this.#wrap = opts.wrap;
    this.#getMaxLoaded = opts.getMaxLoaded ?? (() => undefined);
  }

  /**
   * Identifies the load the accumulator is (or should be) holding. Any change to it means
   * the accumulated pages no longer answer the current question.
   */
  get #loadKey(): string {
    const { filter, nonce, reveal } = this.#state;
    return JSON.stringify([filter, nonce, reveal]);
  }

  rows(opts: SelectLoadRequest): SelectOption[] | Promise<SelectOption[]> {
    return this.#loadServerOptions(this.#state.filter, opts);
  }

  answersSynchronously(): boolean {
    return this.#answeredSynchronously;
  }

  total(): number | undefined {
    if (this.#state.visiblyExhausted) {
      return undefined;
    }
    const { serverComplete, serverLoadedCount, serverTotal, serverTruncated } =
      this.#state;
    return serverComplete && !serverTruncated ? serverLoadedCount : serverTotal;
  }

  canRevealMore(): boolean {
    return !this.pending() && this.mayGrow();
  }

  mayGrow(): boolean {
    const maxLoaded = this.#getMaxLoaded();
    return (
      !this.#state.serverExhausted &&
      !this.#state.visiblyExhausted &&
      (maxLoaded == null || this.#state.serverLoadedCount < maxLoaded)
    );
  }

  atCapWithMore(): boolean {
    const maxLoaded = this.#getMaxLoaded();
    if (maxLoaded == null || this.#state.visiblyExhausted) {
      return false;
    }
    const { serverLoadedCount, serverExhausted, serverTotal, serverTruncated } =
      this.#state;
    return (
      serverTruncated ||
      (serverLoadedCount >= maxLoaded &&
        !serverExhausted &&
        (serverTotal == null || serverLoadedCount < serverTotal))
    );
  }

  pending(): boolean {
    const completed = this.#state.serverCompletedKey;
    return completed != null && completed !== this.#loadKey;
  }

  /** Whether no load has finished yet, so the first page is still on its way. */
  awaitingFirstPage(): boolean {
    return this.#state.serverCompletedKey == null;
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

  queryPending(): boolean {
    const completed = this.#state.serverCompletedKey;
    if (!this.pending() || completed == null) {
      return false;
    }
    const [filter] = JSON.parse(completed) as [string, number, number];
    return filter !== this.#state.filter;
  }

  revealMore(): boolean {
    // `#serverRequest` is the authoritative in-flight check and is read directly because
    // this runs from an action, never during render. `canRevealMore` is its reactive
    // counterpart for gating the sentinel.
    if (this.#serverRequest || !this.canRevealMore()) {
      return false;
    }

    if (
      this.#visibleMeasured &&
      this.#visible != null &&
      this.#visibleAtReveal != null
    ) {
      this.#barrenReveals =
        this.#visible > this.#visibleAtReveal ? 0 : this.#barrenReveals + 1;
      if (this.#barrenReveals >= 2) {
        this.#state.visiblyExhausted = true;
        return false;
      }
    }
    this.#visibleAtReveal = this.#visible;
    this.#visibleMeasured = false;
    this.#state.reveal++;
    return true;
  }

  knownOptions(): readonly SelectOption[] {
    return this.#serverOptions;
  }

  knownRecords(): SelectRecord[] {
    return this.#serverOptions.map((option) => option.record);
  }

  /** Ignores retained rows both during a request and before its new rows reach the list. */
  noteVisible(visible: number, input: number): void {
    if (this.#serverRequest || input !== this.#serverOptions.length) {
      return;
    }
    this.#visible = visible;
    this.#visibleMeasured = true;
  }

  reset(): void {
    this.#state.reveal = 0;
    this.#state.serverTotal = undefined;
    this.#state.serverExhausted = false;
    this.#state.visiblyExhausted = false;
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
    this.#serverOptions = [];
    this.#serverKeys.clear();
    this.#serverOffset = 0;
    this.#serverCursor = undefined;
    this.#serverPage = 1;
    this.#serverPageSize = undefined;
    this.#serverBarrenPages = 0;
    this.#barrenReveals = 0;
    this.#visible = undefined;
    this.#visibleAtReveal = undefined;
    this.#visibleMeasured = false;
    this.#serverGeneration++;
    this.#serverRequest = undefined;
    this.#latestServerRequest = undefined;
    this.#queryLoad = undefined;
  }

  revealToken(): number {
    return this.#state.reveal;
  }

  reactiveOptions(): readonly SelectOption[] {
    return [];
  }

  #loadServerOptions(
    filter: string,
    opts: SelectLoadRequest
  ): SelectOption[] | Promise<SelectOption[]> {
    const maxLoaded = this.#getMaxLoaded();
    if (
      this.#serverRequest ||
      this.#state.serverExhausted ||
      (maxLoaded != null && this.#serverOptions.length >= maxLoaded) ||
      this.#state.serverSettledKey === this.#loadKey
    ) {
      return this.#serverOptions.slice(0, maxLoaded);
    }

    const generation = this.#serverGeneration;
    const key = this.#loadKey;
    const offset = this.#serverOffset;
    const cursor = this.#serverCursor;
    const page = this.#serverPage;
    const limit = this.#serverPageSize;
    // Started after the current task rather than inside it: this runs during render, where a
    // loader writing tracked state would fail the render and its tracked reads would turn into
    // reload triggers. A request abandoned or reset before it starts is never sent.
    const request = Promise.resolve().then(() => {
      if (opts.signal?.aborted || generation !== this.#serverGeneration) {
        return [];
      }
      this.#queryLoad ??= this.#resolveLoad(filter);
      const result = this.#queryLoad(filter, {
        ...opts,
        offset,
        limit,
        cursor,
        page,
      });
      this.#answeredSynchronously =
        typeof (result as PromiseLike<unknown>)?.then !== "function";
      return result;
    });
    this.#serverRequest = request;
    this.#latestServerRequest = request;
    // An abandoned request must not keep answering for the one that replaces it. The consumer
    // aborts on teardown, so a panel closed mid-flight and reopened before the abort settles
    // would otherwise hit the in-flight short-circuit above and be handed the accumulator —
    // empty, on a first page — as a synchronous answer, leaving the query reading "no results"
    // with nothing left to re-ask. Releasing the handle is enough: the generation deliberately
    // does NOT move, so the settle below still stamps `serverCompletedKey` unless a retry has
    // started since (see its comment).
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
  ): Promise<SelectOption[]> {
    let settled = false;
    try {
      const response = await request;
      if (signal?.aborted || generation !== this.#serverGeneration) {
        return this.#serverOptions.slice(0, this.#getMaxLoaded());
      }

      const { options, total, hasMore, cursor } =
        this.#unwrapLoadResult(response);
      const knownTotal = total ?? this.#state.serverTotal;
      const before = this.#serverOptions.length;
      this.#serverPageSize ??= options.length || undefined;
      const truncated = this.#appendServerOptions(options);
      this.#serverOffset += options.length;
      this.#serverCursor = cursor;
      this.#serverPage++;
      const added = this.#serverOptions.length - before;

      // Reachable only under `hasMore: true`, since silence now ends paging on its own. It is
      // the residual brake on a source that claims more forever: tolerating one barren page
      // still supports overlapping pages, and the second stops it.
      this.#serverBarrenPages = added === 0 ? this.#serverBarrenPages + 1 : 0;

      // Against *deduped* rows: the raw cursor outruns them whenever pages overlap, and
      // comparing it here would strand the tail.
      const ceilingReached =
        knownTotal != null && this.#serverOptions.length >= knownTotal;

      // Silence means the set is complete, so only an affirmative signal buys another fetch.
      // An explicit `hasMore: false` is terminal whatever `total` says: a source may report 99
      // matches while permitting only 5, and those 5 are all the user can ever navigate to.
      const moreDeclared =
        hasMore === true ||
        (hasMore == null &&
          knownTotal != null &&
          this.#serverOptions.length < knownTotal);

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
      this.#state.serverLoadedCount = this.#serverOptions.length;
      settled = true;

      return this.#serverOptions.slice(0, this.#getMaxLoaded());
    } finally {
      if (this.#serverRequest === request) {
        this.#serverRequest = undefined;
      }
      if (
        generation === this.#serverGeneration &&
        this.#latestServerRequest === request
      ) {
        // Completion covers rejection AND abort: this request is over either way. Skipping
        // it on abort left the key behind the live one forever, pinning `aria-busy` on and
        // making `canRevealMore` permanently false — the list could never be revealed
        // again. Only the latest request stamps: an abandoned one that settles after its
        // retry and a later reveal would otherwise move the key back to its own load.
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

  #appendServerOptions(options: readonly SelectOption[]): boolean {
    const maxLoaded = this.#getMaxLoaded();
    for (const option of options) {
      const key = this.#keyOf(option);
      if (key != null && this.#serverKeys.has(key)) {
        continue;
      }

      if (maxLoaded != null && this.#serverOptions.length >= maxLoaded) {
        // One discarded unique row proves truncation without scanning the rest of the page.
        return true;
      }

      this.#serverOptions.push(option);
      if (key != null) {
        this.#serverKeys.add(key);
      }
    }

    return false;
  }

  #unwrapLoadResult(response: SelectLoadResult): SelectLoadedPage {
    if (Array.isArray(response)) {
      return { options: this.#wrap(response) };
    }
    assert(
      "DSelect: a loader answers with records, or `{ options, total, hasMore, cursor }`; " +
        "`{ items }` is the old shape.",
      response == null ||
        Array.isArray(response.options) ||
        !("items" in (response as object))
    );
    return { ...response, options: this.#wrap(response?.options ?? []) };
  }
}
