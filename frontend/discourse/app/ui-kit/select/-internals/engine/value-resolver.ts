import { assert } from "@ember/debug";
import { trackedMap } from "@ember/reactive/collections";
import { makeArray } from "discourse/lib/helpers";
import type {
  SelectItem,
  SelectItemId,
  SelectLoadOptions,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import type SelectOptionsView from "./select-options";

interface ValueResolverOptions {
  options: SelectOptionsView;
  knownRows: () => SelectItem[];
}

export default class ValueResolver {
  /**
   * value → resolved item, so a re-render or reopen never re-fetches a label. Keyed by the
   * normalized value (see `SelectOptionsView#valueKey`) so a string/number id mismatch is a
   * cache hit.
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

  #options: SelectOptionsView;

  // The rows already in hand for the current source, whichever kind it is. A paginated
  // source returns its untracked accumulator; without this rung it would refetch a value
  // whose row is already on screen. Read untracked on purpose — this runs during render,
  // and the fetch path already covers the case where the row has not landed yet.
  #knownRows: () => SelectItem[];

  constructor(opts: ValueResolverOptions) {
    this.#options = opts.options;
    this.#knownRows = opts.knownRows;
  }

  resolveSelection(
    value: SelectValue,
    opts: SelectLoadOptions = {}
  ):
    | SelectItem
    | SelectItem[]
    | Promise<SelectItem>
    | Promise<SelectItem[]>
    | undefined {
    if (!this.#options.multiple) {
      if (value == null) {
        return undefined;
      }
      const resolved = this.#resolveMany([value], opts);
      return this.#isPromise<SelectItem[]>(resolved)
        ? this.#firstOf(resolved)
        : resolved[0]!;
    }
    const values = this.#options.dedupeValues(
      makeArray(value) as SelectItemId[]
    );
    // Empty multi → undefined so the trigger shows its placeholder (not an empty list).
    if (values.length === 0) {
      return undefined;
    }
    return this.#resolveMany(values, opts);
  }

  resolveSingleSync(value: SelectValue): SelectItem | undefined {
    if (value == null || Array.isArray(value)) {
      return undefined;
    }
    return this.resolveOneSync(value);
  }

  /** Whether any non-null value currently resolves to an `__unresolved` fallback. */
  hasUnresolved(values: SelectItemId[]): boolean {
    return values.some(
      (value) => value != null && !!this.resolveOneSync(value)?.__unresolved
    );
  }

  isCustomUnresolvedItem(item: SelectItem): boolean {
    return this.#customUnresolvedItems.has(item);
  }

  evictUnresolved(): void {
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
  }

  cacheResolved(item: SelectItem | null | undefined): void {
    if (item) {
      this.#cacheResolvedValue(this.#options.itemValue(item), item);
    }
  }

  /**
   * The item to show for a value: `valueItems` → a real recorded outcome → client list →
   * the fallback left by an earlier failed attempt.
   *
   * An `__unresolved` fallback ranks LAST, so any real source that turns up later — an item
   * landing in the client list, a re-resolve — supersedes it instead of being masked by it.
   * But it is still a hit, deliberately: a resolve records its outcome, and a read that
   * missed would re-resolve, record again, invalidate the render that read it, and never
   * settle. "Failed" has to be a terminal answer; `reload` is what retries it.
   */
  resolveOneSync(value: SelectItemId): SelectItem | undefined {
    const key = this.#options.valueKey(value);
    if (key == null) {
      return undefined;
    }
    const recorded = this.#recordedOutcomes(key);
    return (
      this.#matching(
        makeArray(this.#options.valueItems) as SelectItem[],
        key
      ) ??
      recorded.find((item) => !item.__unresolved) ??
      this.#matching(this.#knownRows(), key) ??
      recorded[0]
    );
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
    const synced = values.map((v) => this.resolveOneSync(v));
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
      const key = this.#options.valueKey(value);
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
   * remains a sync hit, but ranks after real valueItems/cache/list items; `reload()` evicts it
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
    return items.find(
      (i) => this.#options.valueKey(this.#options.itemValue(i)) === key
    );
  }

  // Resolves ids to a key→item map, containing only what genuinely resolved. Never throws
  // and never rejects. One batch call via `resolveValues` when given; otherwise per-id via
  // `resolveValue` (fans out — only when no batch resolver is supplied).
  #resolveBatch(
    values: SelectItemId[],
    opts: SelectLoadOptions
  ): Map<string, SelectItem> | Promise<Map<string, SelectItem>> {
    if (this.#options.resolveValues) {
      const result = this.#attempt(() =>
        this.#options.resolveValues!(values, opts)
      );
      return this.#isPromise(result)
        ? result.then(
            (items) => this.#toResolvedMap(items),
            () => new Map<string, SelectItem>()
          )
        : this.#toResolvedMap(result);
    }
    const per = values.map((v) => {
      const result = this.#attempt(() => this.#options.resolveValue?.(v, opts));
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
        (item) => [this.#options.itemValue(item), item] as const
      )
    );
  }

  #pairsToMap(
    pairs: ReadonlyArray<readonly [SelectItemId, SelectItem | undefined]>
  ): Map<string, SelectItem> {
    const map = new Map<string, SelectItem>();
    for (const [value, item] of pairs) {
      const key = this.#options.valueKey(value);
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
      const key = this.#options.valueKey(v);
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
    // A server source that was never given a way to answer "what is this id" can only ever
    // fabricate this fallback, so the trigger reads "(unavailable)" for the life of the page.
    // It looks correct in the session that picked the value — the cache still holds it — and
    // breaks on the next load, which is why it is worth failing loudly rather than degrading.
    // Stripped from production builds.
    assert(
      `DSelect: no way to resolve the held value \`${String(value)}\`. \`@load\` answers ` +
        `queries and is never asked what a given id is, so a select that can mount holding a ` +
        `value needs \`@resolveValue\`, \`@resolveValues\`, or \`@valueItems\`.`,
      !this.#options.load ||
        !!this.#options.resolveValue ||
        !!this.#options.resolveValues ||
        this.#options.valueItemsDeclared
    );
    const built = this.#options.createUnresolvedItem
      ? this.#attempt(() => this.#options.createUnresolvedItem!(value))
      : undefined;
    if (built) {
      const item = {
        ...built,
        [this.#options.valueField]: value,
        __unresolved: true,
      };
      this.#customUnresolvedItems.add(item);
      return item;
    }
    const item: SelectItem = {
      [this.#options.valueField]: value,
      __unresolved: true,
    };
    // Show the value as the label so an unresolved row renders the id, not a blank — unless
    // the label field IS the value field, where it is already present (keeping the raw type).
    if (this.#options.labelField !== this.#options.valueField) {
      item[this.#options.labelField] = String(value ?? "");
    }
    return item;
  }

  #cacheResolvedValue(
    value: SelectItemId,
    item: SelectItem | null | undefined
  ): void {
    const key = this.#options.valueKey(value);
    if (key != null && item && this.#resolvedCache.get(key) !== item) {
      this.#resolvedCache.set(key, item);
    }
  }

  #isPromise<T>(value: T | Promise<T>): value is Promise<T> {
    return (
      value != null && typeof (value as { then?: unknown }).then === "function"
    );
  }
}
