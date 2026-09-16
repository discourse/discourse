import type Tag from "discourse/models/tag";
import type Store from "discourse/services/store";

/**
 * Valid orderings for the tag list.
 */
export const VALID_TAG_SORTS = ["popular", "name"];

/** Parameters for {@link fetchTags}. */
interface FetchTagsParams {
  /** The store service used to load tags. */
  store: Store;

  /** Maximum number of tags to resolve. */
  count?: number;

  /** Ordering: one of "popular" or "name". */
  sort?: string;
}

/**
 * Shared tag fetcher for tag-rendering blocks. Resolves to the first `count`
 * tags, ordered by total usage ("popular") or alphabetically ("name"), or
 * `null` when there are no tags. Mirrors the `fetch-topic-list` contract so
 * blocks declare it through their `data` hook and stay pure renderers.
 *
 * @param params - The fetch parameters.
 * @returns The resolved tags, or `null` when there are none.
 */
export async function fetchTags({
  store,
  count = 10,
  sort = "popular",
}: FetchTagsParams): Promise<Tag[] | null> {
  // `ignoreUnsent: false` so an aborted/offline request rejects and surfaces
  // the block's loading boundary instead of leaving the skeleton up forever.
  // Matches the `fetch-topic-list` contract.
  const result = (await store.findAll("tag", undefined, {
    ignoreUnsent: false,
  })) as { content?: Tag[] } | Tag[] | null;
  // `store.findAll` resolves a `ResultSet`; read its underlying array via
  // `.content` (iterating the proxy directly is deprecated). A plain array
  // (e.g. a test double) has no `.content`, so fall back to the value itself.
  const tags: Tag[] = result
    ? Array.from((result as { content?: Tag[] }).content ?? (result as Tag[]))
    : [];
  if (!tags.length) {
    return null;
  }

  // `name` and `count` are runtime attributes the store sets on the record;
  // they aren't declared on the `Tag` model's type, so widen for the sort.
  const sorted = [...tags] as Array<Tag & { name?: string; count?: number }>;
  if (sort === "name") {
    sorted.sort((a, b) => (a.name ?? "").localeCompare(b.name ?? ""));
  } else {
    sorted.sort(
      (a, b) => (b.totalCount ?? b.count ?? 0) - (a.totalCount ?? a.count ?? 0)
    );
  }
  return sorted.slice(0, count);
}
