import { DEBUG } from "@glimmer/env";
import { tracked } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { makeArray } from "discourse/lib/helpers";
import type {
  SelectId,
  SelectLoadRequest,
  SelectRecord,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import type SelectArgsView from "./select-args.ts";
import {
  entryRecord,
  isSelectOption,
  recordOf,
  type SelectOptionLike,
} from "./select-option.ts";

interface ValueResolverInit {
  args: SelectArgsView;
  /** The local source's record for a key; empty for a server source. */
  localRecord: (key: string) => SelectRecord | undefined;
  /** The record the extras give a key at rest, whatever the query. */
  extraRecord: (key: string) => SelectRecord | undefined;
  /** The keys the held value holds now. */
  heldKeys: () => ReadonlySet<string | null>;
}

/**
 * Advanced whenever a sighting or fallback is written outside render. Only readers outside
 * async data consume it: a held value's async data reads the stores directly, so a page or an
 * answer landing never re-runs, and so never aborts, a resolve still in flight.
 */
class LedgerRevision {
  @tracked value = 0;
}

/** A batch stays alive while any joined caller still needs its values. */
type PendingResolution = {
  controller: AbortController;
  callers: Set<AbortSignal | undefined>;
  promise: Promise<Map<string, SelectOptionLike>>;
};

/**
 * The record ledger: the one place that decides which record a value key stands for, so every
 * surface and every data edge shares it. The first rule that knows the key wins: `valueRecords`,
 * the local source, the extras at rest, the latest sighting (a pick, an answer or a loaded page,
 * newest first), the asking view's own input, and last the unresolved fallback.
 */
export default class ValueResolver {
  /**
   * Every real record seen, by identity, oldest first: a pick, a resolver answer, or a row a page
   * added. A record answers for the key it names now, so an edit in place moves it. Plain, read
   * through {@link LedgerRevision}: a synchronous resolver's answer is written during render,
   * which a tracked write would fail.
   */
  #seen = new Set<SelectRecord>();

  /** The record last seen for each key, re-checked on every hit; a miss walks the sightings. */
  #seenIndex = new Map<string, SelectRecord>();

  /** The fallback recorded for a key that could not be resolved; outranked by any real record. */
  #fallbacks = new Map<string, SelectRecord>();

  /** The input each pick came from, so its settings show while its key is held. */
  #picks = new Map<string, SelectOptionLike>();

  /**
   * The option each accepted resolver answer came in, by key, with the record it named. A later
   * sighting of another record for the key drops it.
   */
  #answers = new Map<
    string,
    { record: SelectRecord; option: SelectOptionLike }
  >();

  #revision = new LedgerRevision();

  #pending = new Map<string, PendingResolution>();

  /** The engine's fallbacks for values that could not be resolved; only its own copies. */
  #unresolvedRecords = new WeakSet<SelectRecord>();

  // Fallback records that were actually produced by `createUnresolvedRecord`.
  #customUnresolvedRecords = new WeakSet<SelectRecord>();

  #args: SelectArgsView;
  #localRecord: (key: string) => SelectRecord | undefined;
  #extraRecord: (key: string) => SelectRecord | undefined;
  #heldKeys: () => ReadonlySet<string | null>;

  constructor(opts: ValueResolverInit) {
    this.#args = opts.args;
    this.#localRecord = opts.localRecord;
    this.#extraRecord = opts.extraRecord;
    this.#heldKeys = opts.heldKeys;
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
    if (this.#fallbacks.size) {
      this.#fallbacks.clear();
      this.#revision.value++;
    }
  }

  /**
   * Forgets what was seen for keys the value does not hold, when the list starts over. A held
   * key keeps its record, so the trigger and chips never blank while a new query loads. A pick
   * is kept too: the query can clear before the parent applies the value the pick emitted.
   */
  pruneUnheld(): void {
    const held = this.#heldKeys();
    const kept = (key: string | null) =>
      key != null && (held.has(key) || this.#picks.has(key));
    let pruned = false;
    for (const record of [...this.#seen]) {
      if (!kept(this.#keyOf(record))) {
        this.#seen.delete(record);
        pruned = true;
      }
    }
    for (const [key, record] of [...this.#seenIndex]) {
      if (!this.#seen.has(record)) {
        this.#seenIndex.delete(key);
      }
    }
    for (const [key, answer] of [...this.#answers]) {
      if (!this.#seen.has(answer.record)) {
        this.#answers.delete(key);
      }
    }
    for (const key of [...this.#fallbacks.keys()]) {
      if (!kept(key)) {
        this.#fallbacks.delete(key);
        pruned = true;
      }
    }
    if (pruned) {
      this.#revision.value++;
    }
  }

  /**
   * Records the rows a page added as sightings, after the page's await. Every key counts, held
   * or not, so a value held later is already known.
   *
   * @param accepted - The options the page added, by the key the source read for each.
   */
  sightPage(accepted: ReadonlyMap<string, SelectOptionLike>): void {
    for (const [key, option] of accepted) {
      this.#record(key, entryRecord(option));
    }
    if (accepted.size) {
      this.#revision.value++;
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
        this.#args.valueRecordsDeclared ||
        (makeArray(value) as SelectId[]).every((held) => {
          const key = this.#args.valueKey(held);
          return key == null || this.#realRecord(key) !== undefined;
        })
    );
  }

  /**
   * Records a pick as the newest sighting of its key, with the input it came from.
   *
   * @param entry - What was picked: a record, or an option with settings.
   */
  cacheResolved(entry: SelectOptionLike | null | undefined): void {
    if (!entry) {
      return;
    }
    const record = entryRecord(entry);
    const key = this.#args.valueKey(this.#args.recordValue(record));
    if (key == null) {
      return;
    }
    if (this.#record(key, record)) {
      this.#picks.set(key, entry);
    }
    this.#revision.value++;
  }

  /**
   * The record a value stands for now, including a fallback left by an earlier failed attempt.
   * Tracked, for readers outside async data: a sighting landing re-renders them.
   */
  resolveOneSync(value: SelectId): SelectRecord | undefined {
    const key = this.#args.valueKey(value);
    if (key == null) {
      return undefined;
    }
    void this.#revision.value;
    return this.#recordFor(key);
  }

  /**
   * The record a view shows for a key: the ledger's, or the view's own input when nothing else
   * knows the key. Tracked, like {@link resolveOneSync}.
   *
   * @param key - A normalized key.
   * @param input - The view's own input, if it brought one.
   */
  recordForView(
    key: string,
    input: SelectOptionLike | undefined
  ): SelectRecord | undefined {
    void this.#revision.value;
    return (
      this.#realRecord(key) ??
      (input ? (recordOf(input) as SelectRecord) : undefined) ??
      this.#fallbacks.get(key)
    );
  }

  /**
   * The pick that put a held key in the value, while the key stays held.
   *
   * @param key - A normalized key.
   */
  pickFor(key: string): SelectOptionLike | undefined {
    void this.#revision.value;
    return this.#heldKeys().has(key) ? this.#picks.get(key) : undefined;
  }

  /**
   * The option an accepted resolver answer came in, while its record is the one the key stands
   * for.
   *
   * @param key - A normalized key.
   * @param record - The record the key stands for.
   */
  answerFor(key: string, record: SelectRecord): SelectOptionLike | undefined {
    const answer = this.#answers.get(key);
    return answer?.record === record ? answer.option : undefined;
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
    // Read without the revision, so a sighting landing never re-runs the async data asking.
    const synced = values.map((v) => this.#lookUp(v));
    if (synced.every((record) => record != null)) {
      return synced as SelectRecord[];
    }
    let resolved: Map<string, SelectOptionLike> = new Map();
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
            this.#assemble(uncached, [], batch),
            batch
          );
          if (!requests.size) {
            return this.#assemble(values, this.#current(values), resolved);
          }
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
        return this.#assemble(values, synced, resolved);
      }
      for (const batch of batches) {
        for (const [key, record] of batch) {
          resolved.set(key, record);
        }
      }
      // Re-read at settlement: a record that arrived while the request was out outranks what
      // was known when it started.
      return this.#assemble(values, this.#current(values), resolved);
    });
  }

  /**
   * Registers a batch under each of its ids so later resolves join it, caching its outcome unless
   * every caller abandoned it: an aborted request knows nothing about the ids it was asked for.
   */
  #trackRequest(
    values: SelectId[],
    batch: Promise<Map<string, SelectOptionLike>>,
    controller: AbortController
  ): PendingResolution {
    const request: PendingResolution = {
      controller,
      callers: new Set(),
      promise: batch
        .then((resolved) => {
          if (!controller.signal.aborted) {
            this.#cacheOutcome(
              values,
              this.#assemble(values, [], resolved),
              resolved
            );
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
  ): Promise<Map<string, SelectOptionLike>> {
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

  /** Records a synchronous resolver's outcomes. Written during render, so the revision stays. */
  #rememberSynchronousOutcomes(
    values: SelectId[],
    records: SelectRecord[],
    resolved: ReadonlyMap<string, SelectOptionLike>
  ): void {
    values.forEach((value, index) => {
      const key = this.#args.valueKey(value);
      const record = records[index];
      if (key != null && record) {
        this.#accept(key, record, resolved.get(key));
      }
    });
  }

  /**
   * Records the outcome of an async resolve: real records as sightings, so later reads need no
   * fetch, and fallbacks, so a trigger can tell "resolved and failed" from "still resolving".
   * A fallback stays a hit but ranks after every real record; `reload()` evicts it.
   *
   * Only ever called from a promise continuation, after render, so advancing the revision
   * cannot dirty what the render already read.
   */
  #cacheOutcome(
    values: SelectId[],
    records: SelectRecord[],
    resolved: ReadonlyMap<string, SelectOptionLike>
  ): void {
    values.forEach((value, index) => {
      const key = this.#args.valueKey(value);
      const record = records[index];
      if (key != null && record) {
        this.#accept(key, record, resolved.get(key));
      }
    });
    this.#revision.value++;
  }

  /** Stores an accepted outcome, and the settings its answer came with. */
  #accept(
    key: string,
    record: SelectRecord,
    answer: SelectOptionLike | undefined
  ): void {
    if (!this.#record(key, record)) {
      return;
    }
    if (answer && isSelectOption(answer)) {
      this.#answers.set(key, { record, option: answer });
    } else {
      this.#answers.delete(key);
    }
  }

  /** The key a record names now, which an edit in place can change. */
  #keyOf(record: SelectRecord): string | null {
    return this.#args.valueKey(this.#args.recordValue(record));
  }

  /** Every rule that names a real record, `valueRecords` first; untracked for the sightings. */
  #realRecord(key: string): SelectRecord | undefined {
    return (
      this.#args.valueRecordFor(key) ??
      this.#localRecord(key) ??
      this.#extraRecord(key) ??
      this.#sightingFor(key)
    );
  }

  /**
   * The record seen last for a key it still names. A record edited in place to another key
   * moves with its edit, as the source indexes do: a hit is re-checked, and a miss walks the
   * sightings for the newest that names the key.
   */
  #sightingFor(key: string): SelectRecord | undefined {
    const hit = this.#seenIndex.get(key);
    if (hit !== undefined && this.#seen.has(hit) && this.#keyOf(hit) === key) {
      return hit;
    }
    let found: SelectRecord | undefined;
    for (const record of this.#seen) {
      if (this.#keyOf(record) === key) {
        found = record;
      }
    }
    return found;
  }

  /** The ledger's record for a key, a fallback ranking last so a real record supersedes it. */
  #recordFor(key: string): SelectRecord | undefined {
    return this.#realRecord(key) ?? this.#fallbacks.get(key);
  }

  /** The ledger's record for a value, read without consuming the revision. */
  #lookUp(value: SelectId): SelectRecord | undefined {
    const key = this.#args.valueKey(value);
    return key == null ? undefined : this.#recordFor(key);
  }

  /** What the ledger knows for each value now, without consuming the revision. */
  #current(values: SelectId[]): Array<SelectRecord | undefined> {
    return values.map((value) => this.#lookUp(value));
  }

  /**
   * Stores a resolved record: a real one as the key's newest sighting, displacing the record the
   * key held, and a fallback only while no real record is known. Returns whether a real record
   * was stored.
   */
  #record(key: string, record: SelectRecord): boolean {
    if (this.isUnresolvedRecord(record)) {
      if (!this.#sightingFor(key)) {
        this.#fallbacks.set(key, record);
      }
      return false;
    }
    // Only the indexed owner is displaced, so a page costs one key read per row. A record moved
    // onto this key unindexed stays behind, but the index hit and the newest-first walk both
    // rank it below this one.
    const previous = this.#seenIndex.get(key);
    if (
      previous !== undefined &&
      previous !== record &&
      this.#keyOf(previous) === key
    ) {
      this.#seen.delete(previous);
    }
    if (this.#answers.get(key)?.record !== record) {
      this.#answers.delete(key);
    }
    this.#seen.delete(record);
    this.#seen.add(record);
    this.#seenIndex.set(key, record);
    return true;
  }

  // Resolves ids to a key→record map, containing only what genuinely resolved. Never throws
  // and never rejects. One batch call via `resolveValues` when given; otherwise per-id via
  // `resolveValue` (fans out — only when no batch resolver is supplied).
  #resolveBatch(
    values: SelectId[],
    opts: SelectLoadRequest
  ): Map<string, SelectOptionLike> | Promise<Map<string, SelectOptionLike>> {
    const request = { ...opts, config: this.#args.config };
    if (this.#args.resolveValues) {
      const result = this.#attempt(() =>
        this.#args.resolveValues!(values, request)
      );
      return this.#isPromise(result)
        ? result.then(
            (records) => this.#toResolvedMap(records),
            () => new Map<string, SelectOptionLike>()
          )
        : this.#toResolvedMap(result);
    }
    const per = values.map((v) => {
      const result = this.#attempt(() => this.#args.resolveValue?.(v, request));
      return this.#isPromise(result)
        ? result.then(
            (entry) => [v, entry] as const,
            () => [v, undefined] as const
          )
        : ([v, result] as const);
    });
    return per.some((r) => this.#isPromise(r))
      ? Promise.all(per).then((pairs) => this.#pairsToMap(pairs))
      : this.#pairsToMap(
          per as ReadonlyArray<
            readonly [SelectId, SelectOptionLike | undefined]
          >
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
  ): Map<string, SelectOptionLike> {
    return this.#pairsToMap(
      (makeArray(records) as SelectOptionLike[]).map(
        (entry) => [this.#args.recordValue(entryRecord(entry)), entry] as const
      )
    );
  }

  #pairsToMap(
    pairs: ReadonlyArray<readonly [SelectId, SelectOptionLike | undefined]>
  ): Map<string, SelectOptionLike> {
    const map = new Map<string, SelectOptionLike>();
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
    resolved: Map<string, SelectOptionLike>
  ): SelectRecord[] {
    return values.map((v, index) => {
      const key = this.#args.valueKey(v);
      return (
        synced[index] ??
        this.#resolvedRecord(resolved, key) ??
        this.#unresolvedRecord(v)
      );
    });
  }

  #resolvedRecord(
    resolved: ReadonlyMap<string, SelectOptionLike>,
    key: string | null
  ): SelectRecord | undefined {
    const entry = key == null ? undefined : resolved.get(key);
    return entry === undefined ? undefined : entryRecord(entry);
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

  #isPromise<T>(value: T | Promise<T>): value is Promise<T> {
    return (
      value != null && typeof (value as { then?: unknown }).then === "function"
    );
  }
}
