// @ts-check

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

/**
 * Shared user fetcher for contributor-rendering blocks. Resolves to the first
 * `count` directory items for the given period, ranked by `order`, or `null`
 * when the directory is empty. Each item carries a `.user` plus the ranked
 * metric. Mirrors the `fetch-topic-list` contract so blocks declare it through
 * their `data` hook and stay pure renderers.
 *
 * @param {object} params
 * @param {import("discourse/services/store").default} params.store
 * @param {string} [params.period="weekly"]
 * @param {string} [params.order="likes_received"]
 * @param {number} [params.count=5]
 * @returns {Promise<Array<Object> | null>}
 */
export async function fetchUsers({
  store,
  period = "weekly",
  order = "likes_received",
  count = 5,
}) {
  const result = await store.find(
    "directoryItem",
    { period, order, asc: false },
    { ignoreUnsent: false }
  );
  // `store.find` resolves a `ResultSet`; read its underlying array via
  // `.content` (iterating the proxy directly is deprecated). A plain array
  // (e.g. a test double) has no `.content`, so fall back to the value itself.
  const items = result ? Array.from(result.content ?? result) : [];
  if (!items.length) {
    return null;
  }
  return items.slice(0, count);
}
