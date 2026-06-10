// @ts-check

/**
 * Valid orderings for the tag list.
 */
export const VALID_TAG_SORTS = ["popular", "name"];

/**
 * Shared tag fetcher for tag-rendering blocks. Resolves to the first `count`
 * tags, ordered by total usage ("popular") or alphabetically ("name"), or
 * `null` when there are no tags. Mirrors the `fetch-topic-list` contract so
 * blocks declare it through their `data` hook and stay pure renderers.
 *
 * @param {object} params
 * @param {import("discourse/services/store").default} params.store
 * @param {number} [params.count=10]
 * @param {string} [params.sort="popular"] - One of "popular" or "name".
 * @returns {Promise<Array<import("discourse/models/tag").default> | null>}
 */
export async function fetchTags({ store, count = 10, sort = "popular" }) {
  // `ignoreUnsent: false` so an aborted/offline request rejects and surfaces
  // the block's loading boundary instead of leaving the skeleton up forever.
  // Matches the `fetch-topic-list` contract.
  const result = await store.findAll("tag", undefined, {
    ignoreUnsent: false,
  });
  // `store.findAll` resolves a `ResultSet`; read its underlying array via
  // `.content` (iterating the proxy directly is deprecated). A plain array
  // (e.g. a test double) has no `.content`, so fall back to the value itself.
  const tags = result ? Array.from(result.content ?? result) : [];
  if (!tags.length) {
    return null;
  }

  const sorted = [...tags];
  if (sort === "name") {
    sorted.sort((a, b) => (a.name ?? "").localeCompare(b.name ?? ""));
  } else {
    sorted.sort(
      (a, b) => (b.totalCount ?? b.count ?? 0) - (a.totalCount ?? a.count ?? 0)
    );
  }
  return sorted.slice(0, count);
}
