import type Store from "discourse/services/store";

/**
 * Valid leaderboard periods for the user list.
 */
export const VALID_USER_PERIODS = [
  "daily",
  "weekly",
  "monthly",
  "quarterly",
  "yearly",
  "all",
];

/**
 * Valid orderings for the user list — the directory metrics a contributor can
 * be ranked by.
 */
export const VALID_USER_ORDERS = [
  "likes_received",
  "likes_given",
  "post_count",
  "topic_count",
  "days_visited",
];

/** Parameters for {@link fetchUsers}. */
interface FetchUsersParams {
  /** The store service used to load directory items. */
  store: Store;

  /** The leaderboard period (one of {@link VALID_USER_PERIODS}). */
  period?: string;

  /** The ranking metric (one of {@link VALID_USER_ORDERS}). */
  order?: string;

  /** Maximum number of items to resolve. */
  count?: number;
}

/**
 * Shared user fetcher for contributor-rendering blocks. Resolves to the first
 * `count` directory items for the given period, ranked by `order`, or `null`
 * when the directory is empty. Each item carries a `.user` plus the ranked
 * metric. Mirrors the `fetch-topic-list` contract so blocks declare it through
 * their `data` hook and stay pure renderers.
 *
 * @param params - The fetch parameters.
 * @returns The resolved directory items, or `null` when the directory is empty.
 */
export async function fetchUsers({
  store,
  period = "weekly",
  order = "likes_received",
  count = 5,
}: FetchUsersParams): Promise<object[] | null> {
  const result = (await store.find(
    "directoryItem",
    { period, order, asc: false },
    { ignoreUnsent: false }
  )) as { content?: object[] } | object[] | null;
  // `store.find` resolves a `ResultSet`; read its underlying array via
  // `.content` (iterating the proxy directly is deprecated). A plain array
  // (e.g. a test double) has no `.content`, so fall back to the value itself.
  const items: object[] = result
    ? Array.from(
        (result as { content?: object[] }).content ?? (result as object[])
      )
    : [];
  if (!items.length) {
    return null;
  }
  return items.slice(0, count);
}
