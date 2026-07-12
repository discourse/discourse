import type Owner from "@ember/owner";
import { TrackedAsyncData } from "ember-async-data";
import type { BlockDataDeclaration } from "discourse/blocks/types";
import PreloadStore from "discourse/lib/preload-store";

/** A resolved (or in-flight) cache entry: the async data and its promise. */
interface BlockDataCacheEntry {
  data: TrackedAsyncData<unknown>;
  promise: Promise<unknown>;
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
 * decorator (a `request` that maps args to a serializable descriptor and a
 * `resolve` that turns a descriptor into data). This module resolves that need
 * and caches the result so the block can render with its data already in hand.
 *
 * Resolution prefers a value the server inlined into the preload store — keyed
 * by the block name plus its descriptor — and otherwise runs the block's own
 * resolver. Because the key is derived from the descriptor, the server and the
 * client compute the same key independently.
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
  // Prefer a server-inlined payload. Read it once and remove it: later
  // requests for the same key hit the cache below, not the preload store.
  if (PreloadStore.has(key)) {
    const raw = PreloadStore.get(key);
    PreloadStore.remove(key);
    return dataMeta.hydrate ? dataMeta.hydrate(raw, { owner }) : raw;
  }

  return dataMeta.resolve(descriptor, { owner, signal });
}

// Ensures resolution for one descriptor is started and cached, returning the
// cache entry ({ data, promise }). Returns null when the block declares no
// data for the current args (a null descriptor) or has no resolver.
export function loadBlockData({
  scope,
  blockName,
  descriptor,
  dataMeta,
  owner,
  signal,
}: LoadBlockDataOptions): BlockDataCacheEntry | null {
  if (descriptor == null || typeof dataMeta?.resolve !== "function") {
    return null;
  }

  const key = blockDataKey(blockName, descriptor);
  const entries = scopeCache(scope);

  const existing = entries.get(key);
  if (existing) {
    return existing;
  }

  const promise = resolveData(key, descriptor, dataMeta, owner, signal);
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
