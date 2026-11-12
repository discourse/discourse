import { DEBUG } from "@glimmer/env";
import { assert } from "@ember/debug";
import { trackedMap } from "@ember/reactive/collections";
import { makeArray } from "discourse/lib/helpers";
import type {
  SelectId,
  SelectLoadRequest,
  SelectRecord,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import type SelectArgsView from "./select-args.ts";
import { entryRecord, type SelectOptionLike } from "./select-option.ts";

interface ValueResolverInit {
  args: SelectArgsView;
  knownRecords: () => SelectRecord[];
}

/** A batch stays alive while any joined caller still needs its values. */
type PendingResolution = {
  controller: AbortController;
  callers: Set<AbortSignal | undefined>;
  promise: Promise<Map<string, SelectRecord>>;
};

export default class ValueResolver {
  /**
   * value → resolved record, so a re-render or reopen never re-fetches a label. Keyed by the
   * normalized value (see `SelectArgsView#valueKey`) so a string/number id mismatch is a
   * cache hit.
   */
  #resolvedCache = trackedMap<string, SelectRecord>();

  /**
   * The same, for outcomes a synchronous resolver produced, which the trigger still has to
   * read later in the same render. Deliberately untracked: `#resolveMany` runs during a
   * render that already consumed `#resolvedCache`, so writing that tracked map here would
   * invalidate the very computation performing the write.
   */
  #synchronousOutcomes = new Map<string, SelectRecord>();

  #pending = new Map<string, PendingResolution>();

  /** The engine's fallbacks for values that could not be resolved; only its own copies. */
  #unresolvedRecords = new WeakSet<SelectRecord>();

  // Fallback records that were actually produced by `createUnresolvedRecord`.
  #customUnresolvedRecords = new WeakSet<SelectRecord>();

  #args: SelectArgsView;

  // The records already in hand for the current source, whichever kind it is. A paginated
  // source returns its untracked accumulator; without this rung it would refetch a value
  // whose row is already on screen. Read untracked on purpose — this runs during render,
  // and the fetch path already covers the case where the row has not landed yet.
  #knownRecords: () => SelectRecord[];

  constructor(opts: ValueResolverInit) {
    this.#args = opts.args;
    this.#knownRecords = opts.knownRecords;
  }

  resolveSelection(
    value: SelectValue,
    opts: SelectLoadRequest = {}
  ):
    | SelectRecord
    | SelectRecord[]
    | Promise<SelectRecord>
    | Promise<SelectRecord[]>
    | undefined {
    if (!this.#args.multiple) {
      const single = this.#args.singleValue(value);
      if (single == null) {
        return undefined;
      }
      const resolved = this.#resolveMany([single], opts);
      return this.#isPromise<SelectRecord[]>(resolved)
        ? this.#firstOf(resolved)
        : resolved[0]!;
    }
    const values = this.#args.dedupeValues(makeArray(value) as SelectId[]);
    // Empty multi → undefined so the trigger shows its placeholder (not an empty list).
    if (values.length === 0) {
      return undefined;
    }
    return this.#resolveMany(values, opts);
  }

  resolveSingleSync(value: SelectValue): SelectRecord | undefined {
    if (value == null || Array.isArray(value)) {
      return undefined;
    }
    return this.resolveOneSync(value);
  }

  /** Whether any non-null value currently resolves to an unresolved fallback. */
  hasUnresolved(values: SelectId[]): boolean {
    return values.some((value) => {
      const record = value == null ? undefined : this.resolveOneSync(value);
      return !!record && this.isUnresolvedRecord(record);
    });
  }

  isUnresolvedRecord(record: SelectRecord): boolean {
    return this.#unresolvedRecords.has(record);
  }

  isCustomUnresolvedRecord(record: SelectRecord): boolean {
    return this.#customUnresolvedRecords.has(record);
  }

  evictUnresolved(): void {
    for (const [key, record] of [...this.#resolvedCache.entries()]) {
      if (this.isUnresolvedRecord(record)) {
        this.#resolvedCache.delete(key);
      }
    }
    for (const [key, record] of this.#synchronousOutcomes) {
      if (this.isUnresolvedRecord(record)) {
        this.#synchronousOutcomes.delete(key);
      }
    }
  }

  /**
   * Asserts that a held value can be resolved at all. A server source that was never given a
   * way to answer "what is this id" can only ever fabricate the unresolved fallback, so
   * the trigger shows the value as unavailable for the life of the page. It looks correct in the
   * session that picked the value, because the cache still holds it, and breaks on the next
   * load. That is why it fails loudly rather than degrading. Stripped from production builds.
   *
   * @param value - The held value, named in the message.
   */
  assertCanResolve(value: SelectValue): void {
    assert(
      `DSelect: no way to resolve the held value \`${String(value)}\`. \`@load\` answers ` +
        `queries and is never asked what a given id is, so a select that can mount holding a ` +
        `value needs \`@resolveValue\`, \`@resolveValues\`, or \`@valueRecords\`.`,
      !this.#args.load ||
        !!this.#args.resolveValue ||
        !!this.#args.resolveValues ||
        this.#args.valueRecordsDeclared
    );
  }

  cacheResolved(record: SelectRecord | null | undefined): void {
    if (record) {
      this.#cacheResolvedValue(this.#args.recordValue(record), record);
    }
  }

  /**
   * The record to show for a value: `valueRecords` → a real recorded outcome → client list →
   * the fallback left by an earlier failed attempt.
   *
   * An unresolved fallback ranks LAST, so any real source that turns up later — a record
   * landing in the client list, a re-resolve — supersedes it instead of being masked by it.
   * But it is still a hit, deliberately: a resolve records its outcome, and a read that
   * missed would re-resolve, record again, invalidate the render that read it, and never
   * settle. "Failed" has to be a terminal answer; `reload` is what retries it.
   */
  resolveOneSync(value: SelectId): SelectRecord | undefined {
    const key = this.#args.valueKey(value);
    if (key == null) {
      return undefined;
    }
    const recorded = this.#recordedOutcomes(key);
    return (
      this.#matching(
        (makeArray(this.#args.valueRecords) as SelectOptionLike[]).map(
          entryRecord
        ),
        key
      ) ??
      recorded.find((record) => !this.isUnresolvedRecord(record)) ??
      this.#matching(this.#knownRecords(), key) ??
      recorded[0]
    );
  }

  // Narrows a resolved batch back to the single arity. `#resolveMany` always yields at least
  // one record per requested id, so index 0 is present.
  async #firstOf(records: Promise<SelectRecord[]>): Promise<SelectRecord> {
    return (await records)[0]!;
  }

  /**
   * Ordered records for `values`: the sync ladder for what is already known, the pending request
   * for ids already being fetched, one batch call for the rest, and an unresolved fallback
   * for whatever still doesn't resolve. Order follows the bound ids, not the response. Never
   * rejects.
   */
  #resolveMany(
    values: SelectId[],
    opts: SelectLoadRequest
  ): SelectRecord[] | Promise<SelectRecord[]> {
    const synced = values.map((v) => this.resolveOneSync(v));
    if (synced.every((record) => record != null)) {
      return synced as SelectRecord[];
    }
    let resolved = new Map<string, SelectRecord>();
    if (opts.signal?.aborted) {
      return this.#assemble(values, synced, resolved);
    }
    const requests = new Set<PendingResolution>();
    const uncached = values.filter((value, index) => {
      if (synced[index] != null) {
        return false;
      }
      const key = this.#args.valueKey(value);
      const pending = key == null ? undefined : this.#pending.get(key);
      if (pending && !pending.controller.signal.aborted) {
        requests.add(pending);
        return false;
      }
      return true;
    });
    if (uncached.length) {
      const controller = new AbortController();
      const batch = this.#resolveBatch(uncached, {
        ...opts,
        signal: controller.signal,
      });
      if (this.#isPromise(batch)) {
        requests.add(this.#trackRequest(uncached, batch, controller));
      } else {
        resolved = batch;
        if (!opts.signal?.aborted) {
          // A synchronous result must not dirty the tracked cache consumed during render.
          this.#rememberSynchronousOutcomes(
            uncached,
            [],
            this.#assemble(uncached, [], batch)
          );
        }
      }
    }
    if (!requests.size) {
      return this.#assemble(values, synced, resolved);
    }
    return Promise.all(
      [...requests].map((request) => this.#joinRequest(request, opts.signal))
    ).then((batches) => {
      if (opts.signal?.aborted) {
        resolved.clear();
      } else {
        for (const batch of batches) {
          for (const [key, record] of batch) {
            resolved.set(key, record);
          }
        }
      }
      return this.#assemble(values, synced, resolved);
    });
  }

  /**
   * Registers a batch under each of its ids so later resolves join it, caching its outcome unless
   * every caller abandoned it: an aborted request knows nothing about the ids it was asked for.
   */
  #trackRequest(
    values: SelectId[],
    batch: Promise<Map<string, SelectRecord>>,
    controller: AbortController
  ): PendingResolution {
    const request: PendingResolution = {
      controller,
      callers: new Set(),
      promise: batch
        .then((resolved) => {
          if (!controller.signal.aborted) {
            this.#cacheOutcome(values, this.#assemble(values, [], resolved));
          }
          return resolved;
        })
        .finally(() => {
          for (const value of values) {
            const key = this.#args.valueKey(value);
            if (key != null && this.#pending.get(key) === request) {
              this.#pending.delete(key);
            }
          }
        }),
    };
    for (const value of values) {
      const key = this.#args.valueKey(value);
      if (key != null) {
        this.#pending.set(key, request);
      }
    }
    return request;
  }

  /**
   * Waits on a shared request for one caller. A caller's abort settles only that caller; the
   * request itself aborts once no joined caller is still waiting.
   */
  #joinRequest(
    request: PendingResolution,
    signal: AbortSignal | undefined
  ): Promise<Map<string, SelectRecord>> {
    request.callers.add(signal);
    return new Promise((resolve) => {
      const onAbort = () => {
        if ([...request.callers].every((caller) => caller?.aborted)) {
          request.controller.abort();
        }
        resolve(new Map());
      };
      signal?.addEventListener("abort", onAbort, { once: true });
      if (signal?.aborted) {
        onAbort();
      }
      void request.promise.then((resolved) => {
        signal?.removeEventListener("abort", onAbort);
        resolve(signal?.aborted ? new Map() : resolved);
      });
    });
  }

  #rememberSynchronousOutcomes(
    values: SelectId[],
    synced: Array<SelectRecord | undefined>,
    records: SelectRecord[]
  ): void {
    values.forEach((value, index) => {
      const key = this.#args.valueKey(value);
      const record = records[index];
      if (synced[index] == null && key != null && record) {
        this.#synchronousOutcomes.set(key, record);
      }
    });
  }

  /**
   * Records the outcome of an async resolve: real records, so later reads hit the cache
   * instead of refetching, and unresolved fallbacks, so a trigger can tell "resolved and
   * failed" (show the fallback) from "still resolving" (show nothing). A cached fallback
   * remains a sync hit, but ranks after real valueRecords/cache/list records; `reload()` evicts it
   * when the caller explicitly retries.
   *
   * Only ever called from a promise continuation, i.e. a microtask after render, where
   * writing tracked state cannot dirty what the render already read.
   */
  #cacheOutcome(values: SelectId[], records: SelectRecord[]): void {
    values.forEach((value, index) => {
      const record = records[index];
      if (record) {
        this.#cacheResolvedValue(value, record);
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
  #recordedOutcomes(key: string): SelectRecord[] {
    return [
      this.#resolvedCache.get(key),
      this.#synchronousOutcomes.get(key),
    ].filter((record) => record != null);
  }

  #matching(records: SelectRecord[], key: string): SelectRecord | undefined {
    return records.find(
      (i) => this.#args.valueKey(this.#args.recordValue(i)) === key
    );
  }

  // Resolves ids to a key→record map, containing only what genuinely resolved. Never throws
  // and never rejects. One batch call via `resolveValues` when given; otherwise per-id via
  // `resolveValue` (fans out — only when no batch resolver is supplied).
  #resolveBatch(
    values: SelectId[],
    opts: SelectLoadRequest
  ): Map<string, SelectRecord> | Promise<Map<string, SelectRecord>> {
    const request = { ...opts, config: this.#args.config };
    if (this.#args.resolveValues) {
      const result = this.#attempt(() =>
        this.#args.resolveValues!(values, request)
      );
      return this.#isPromise(result)
        ? result.then(
            (records) => this.#toResolvedMap(records),
            () => new Map<string, SelectRecord>()
          )
        : this.#toResolvedMap(result);
    }
    const per = values.map((v) => {
      const result = this.#attempt(() => this.#args.resolveValue?.(v, request));
      return this.#isPromise(result)
        ? result.then(
            (entry) => [v, entry && entryRecord(entry)] as const,
            () => [v, undefined] as const
          )
        : ([v, result && entryRecord(result)] as const);
    });
    return per.some((r) => this.#isPromise(r))
      ? Promise.all(per).then((pairs) => this.#pairsToMap(pairs))
      : this.#pairsToMap(
          per as ReadonlyArray<readonly [SelectId, SelectRecord | undefined]>
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

  // Keys the batch response by each record's OWN id, so a resolver that answers with a record
  // whose id differs from the one requested leaves the requested id unresolved rather than
  // silently mis-pairing the two.
  #toResolvedMap(
    records: SelectRecord[] | null | undefined
  ): Map<string, SelectRecord> {
    return this.#pairsToMap(
      (makeArray(records) as SelectOptionLike[]).map((entry) => {
        const record = entryRecord(entry);
        return [this.#args.recordValue(record), record] as const;
      })
    );
  }

  #pairsToMap(
    pairs: ReadonlyArray<readonly [SelectId, SelectRecord | undefined]>
  ): Map<string, SelectRecord> {
    const map = new Map<string, SelectRecord>();
    for (const [value, record] of pairs) {
      const key = this.#args.valueKey(value);
      if (key != null && record) {
        map.set(key, record);
      }
    }
    return map;
  }

  // Builds the ordered array from the sync hits and the batch results, filling any id that
  // still did not resolve with an unresolved fallback. Order follows `values`, not the
  // response. Pure — caching the outcome is `#cacheOutcome`'s job, and only off-render.
  #assemble(
    values: SelectId[],
    synced: Array<SelectRecord | undefined>,
    resolved: Map<string, SelectRecord>
  ): SelectRecord[] {
    return values.map((v, index) => {
      const key = this.#args.valueKey(v);
      return (
        synced[index] ??
        (key == null ? undefined : resolved.get(key)) ??
        this.#unresolvedRecord(v)
      );
    });
  }

  // The fallback for a held id that could not be resolved. `createUnresolvedRecord` names it
  // ("Topic #123"); the default shows the bare id. Either way the engine owns the
  // unresolved marker, so a builder cannot hand back something that reads as resolved.
  #unresolvedRecord(value: SelectId): SelectRecord {
    // Catches a value set after mount that misses the cache. Here it runs inside the
    // trigger's async data source, which turns the throw into a rejection, so the common
    // case is also checked when the engine is built.
    if (DEBUG) {
      this.assertCanResolve(value);
    }
    const built = this.#args.createUnresolvedRecord
      ? this.#attempt(() =>
          this.#args.createUnresolvedRecord!(value, this.#args.config)
        )
      : undefined;
    if (built) {
      // A copy, so the hook's own object is never marked and a later real resolution
      // returning it reads as resolved.
      const record = {
        ...entryRecord(built),
        [this.#args.valueField]: value,
      };
      this.#unresolvedRecords.add(record);
      this.#customUnresolvedRecords.add(record);
      return record;
    }
    const record: SelectRecord = {
      [this.#args.valueField]: value,
    };
    this.#unresolvedRecords.add(record);
    // Show the value as the label so an unresolved row renders the id, not a blank — unless
    // the label field IS the value field, where it is already present (keeping the raw type).
    if (this.#args.labelField !== this.#args.valueField) {
      record[this.#args.labelField] = String(value ?? "");
    }
    return record;
  }

  #cacheResolvedValue(
    value: SelectId,
    record: SelectRecord | null | undefined
  ): void {
    const key = this.#args.valueKey(value);
    if (key == null || !record) {
      return;
    }
    if (
      this.isUnresolvedRecord(record) &&
      this.#recordedOutcomes(key).some(
        (cached) => !this.isUnresolvedRecord(cached)
      )
    ) {
      return;
    }
    if (this.#resolvedCache.get(key) !== record) {
      this.#resolvedCache.set(key, record);
    }
  }

  #isPromise<T>(value: T | Promise<T>): value is Promise<T> {
    return (
      value != null && typeof (value as { then?: unknown }).then === "function"
    );
  }
}
