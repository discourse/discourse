import type Owner from "@ember/owner";
import { TrackedAsyncData } from "ember-async-data";
import type {
  BlockDataDeclaration,
  BlockDataSource,
} from "discourse/blocks/types";
import PreloadStore from "discourse/lib/preload-store";

/** A resolved (or in-flight) cache entry: the async data and its promise. */
interface BlockDataCacheEntry {
  data: TrackedAsyncData<unknown>;
  promise: Promise<unknown>;
}

/** A promise whose outcome is controlled by a later batch flush. */
interface Deferred {
  promise: Promise<unknown>;
  resolve: (value: unknown) => void;
  reject: (reason?: unknown) => void;
}

/** One cache miss waiting for its source's next batch flush. */
interface PendingBatchItem extends Deferred {
  descriptor: unknown;
  owner?: Owner;
  signal?: AbortSignal;
}

/** The arguments shared by {@link loadBlockData} and {@link getBlockData}. */
interface LoadBlockDataOptions {
  /** The cache namespace (an outlet name). */
  scope: string;

  /** The block's name, part of the derived cache/preload key. */
  blockName: string;

  /** The serializable request descriptor, or `null` when the block wants none. */
  descriptor: unknown;

  /** The block's declared data dependency. */
  dataMeta?: BlockDataDeclaration | null;

  /** The owner passed through to the block's resolver/hydrator. */
  owner?: Owner;

  /** An abort signal passed through to the block's resolver. */
  signal?: AbortSignal;
}

/*
 * Per-block data coordination.
 *
 * A block declares its data need through the `data` option on the block
 * decorator. A declaration maps args to a serializable descriptor and either
 * resolves it inline or delegates it to a shared source. This module resolves
 * that need and caches the result so the block can render with its data already
 * in hand.
 *
 * Resolution prefers a value the server inlined into the preload store — keyed
 * by the block or named source plus its descriptor — and otherwise runs the
 * inline or source resolver. Batch-capable sources collect cache misses in the
 * same microtask window and resolve them together. Because the key is derived
 * from the descriptor, the server and the client compute the same key
 * independently.
 *
 * Two entry points share one cache:
 *   - Before render (a route, inside a transition): `loadBlockData` starts
 *     resolution and returns a promise the caller can await, so the block
 *     paints filled-in with no loading state.
 *   - At render (the layout wrapper): `getBlockData` reads the cache, starting
 *     resolution on a miss and returning a still-pending result that the
 *     wrapper renders a placeholder for.
 *
 * The cache is namespaced per scope (an outlet name) so a layout teardown or
 * replacement drops only that outlet's entries.
 */

// scope -> (key -> { data: TrackedAsyncData, promise: Promise })
const cache = new Map<string, Map<string, BlockDataCacheEntry>>();

// Source identity -> cache misses collected during the current microtask window.
const pendingBatches = new Map<BlockDataSource, PendingBatchItem[]>();
let batchFlushScheduled = false;

function scopeCache(scope: string): Map<string, BlockDataCacheEntry> {
  let entries = cache.get(scope);
  if (!entries) {
    entries = new Map();
    cache.set(scope, entries);
  }
  return entries;
}

// Deterministic serialization so two blocks requesting the same data share one
// entry, and so a server can reproduce the key. Object keys are sorted;
// descriptors are expected to be shallow, JSON-serializable values.
function stableStringify(value: unknown): string {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value) ?? "null";
  }

  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`;
  }

  const record = value as Record<string, unknown>;
  const keys = Object.keys(record).sort();
  return `{${keys
    .map((key) => `${JSON.stringify(key)}:${stableStringify(record[key])}`)
    .join(",")}}`;
}

// The cache / preload key for a block's resolved data. Part of the contract a
// server matches when it inlines a payload into the preload store.
export function blockDataKey(blockName: string, descriptor: unknown): string {
  return `block-data:${blockName}:${stableStringify(descriptor)}`;
}

async function resolveData(
  key: string,
  descriptor: unknown,
  dataMeta: BlockDataDeclaration,
  owner: Owner | undefined,
  signal: AbortSignal | undefined
): Promise<unknown> {
  const source = dataMeta.source;

  // Prefer a server-inlined payload. Read it once and remove it: later
  // requests for the same key hit the cache below, not the preload store.
  if (PreloadStore.has(key)) {
    const raw = PreloadStore.get(key);
    PreloadStore.remove(key);
    const hydrate = source?.hydrate ?? dataMeta.hydrate;
    return hydrate ? hydrate(raw, { owner }) : raw;
  }

  if (source) {
    return source.resolve!(descriptor, { owner, signal });
  }

  return dataMeta.resolve!(descriptor, { owner, signal });
}

function deferred(): Deferred {
  let resolve!: (value: unknown) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<unknown>((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, resolve, reject };
}

function sharedSignal(items: PendingBatchItem[]): AbortSignal | undefined {
  const signal = items[0]?.signal;
  return signal && items.every((item) => item.signal === signal)
    ? signal
    : undefined;
}

async function flushBatch(
  source: BlockDataSource,
  items: PendingBatchItem[]
): Promise<void> {
  const batch = source.batch!;
  const owner = items[0]?.owner;

  try {
    const request = batch.request(items.map((item) => item.descriptor));
    const signal = sharedSignal(items);
    const response = await batch.resolve(request, {
      owner,
      ...(signal ? { signal } : {}),
    });

    for (const item of items) {
      try {
        item.resolve(batch.extract(response, item.descriptor, { owner }));
      } catch (error) {
        item.reject(error);
      }
    }
  } catch (error) {
    for (const item of items) {
      item.reject(error);
    }
  }
}

function flushPendingBatches(): void {
  batchFlushScheduled = false;

  // Detach this window before resolving it. New misses form a later window,
  // and clearing a scope cache cannot discard promises already being flushed.
  const groups = [...pendingBatches];
  pendingBatches.clear();

  for (const [source, items] of groups) {
    void flushBatch(source, items);
  }
}

function enqueueBatch(
  source: BlockDataSource,
  descriptor: unknown,
  owner: Owner | undefined,
  signal: AbortSignal | undefined
): Promise<unknown> {
  const item = { ...deferred(), descriptor, owner, signal };
  const items = pendingBatches.get(source);
  if (items) {
    items.push(item);
  } else {
    pendingBatches.set(source, [item]);
  }

  if (!batchFlushScheduled) {
    batchFlushScheduled = true;
    queueMicrotask(flushPendingBatches);
  }

  return item.promise;
}

// Ensures resolution for one descriptor is started and cached, returning the
// cache entry ({ data, promise }). Returns null when the block declares no
// data for the current args (a null descriptor) or has no resolver or source.
export function loadBlockData({
  scope,
  blockName,
  descriptor,
  dataMeta,
  owner,
  signal,
}: LoadBlockDataOptions): BlockDataCacheEntry | null {
  if (
    descriptor == null ||
    (!dataMeta?.source && typeof dataMeta?.resolve !== "function")
  ) {
    return null;
  }

  const key = blockDataKey(dataMeta.source?.name ?? blockName, descriptor);
  const entries = scopeCache(scope);

  const existing = entries.get(key);
  if (existing) {
    return existing;
  }

  let promise;
  if (dataMeta.source?.batch && !PreloadStore.has(key)) {
    promise = enqueueBatch(dataMeta.source, descriptor, owner, signal);
  } else {
    promise = resolveData(key, descriptor, dataMeta, owner, signal);
  }
  const entry = { data: new TrackedAsyncData(promise), promise };
  entries.set(key, entry);

  // Evict a failed entry so a later mount can retry rather than replaying the
  // rejection. The cache only memoizes successful (or in-flight) resolutions.
  promise.catch(() => {
    if (entries.get(key) === entry) {
      entries.delete(key);
    }
  });

  return entry;
}

// Render-path accessor: the resolved-or-pending TrackedAsyncData for a
// descriptor, or null when the block declares no data.
export function getBlockData(
  options: LoadBlockDataOptions
): TrackedAsyncData<unknown> | null {
  return loadBlockData(options)?.data ?? null;
}

// Drops cached entries for one scope (outlet teardown / layout replacement), or
// all scopes when called with no argument (used to reset between tests).
export function resetBlockData(scope?: string): void {
  if (scope === undefined) {
    cache.clear();
  } else {
    cache.delete(scope);
  }
}
