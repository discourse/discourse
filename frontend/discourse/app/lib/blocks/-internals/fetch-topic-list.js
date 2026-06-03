// @ts-check
import Category from "discourse/models/category";

const USER_ONLY_FILTERS = new Set(["new", "unread"]);

/**
 * Builds the topic-list filter path for a filter type combined with an
 * optional category and tag. Mirrors core's URL conventions so
 * `store.findFiltered` resolves to the right endpoint.
 *
 * @param {string} filterType
 * @param {number} [categoryId]
 * @param {string} [tag]
 * @returns {string}
 */
function buildFilterPath(filterType, categoryId, tag) {
  if (categoryId && tag) {
    const category = Category.findById(categoryId);
    if (category) {
      return `tags/c/${Category.slugFor(category)}/${category.id}/${tag}/l/${filterType}`;
    }
  }
  if (categoryId) {
    const category = Category.findById(categoryId);
    if (category) {
      return `c/${Category.slugFor(category)}/${category.id}/l/${filterType}`;
    }
  }
  if (tag) {
    return `tag/${tag}/l/${filterType}`;
  }
  return filterType;
}

/**
 * Shared topic-list fetcher used by topic-rendering blocks. Resolves to
 * the first `count` topics matching the supplied filter, or `null` when
 * the list is empty or the filter requires a signed-in user that the
 * caller doesn't have.
 *
 * @param {object} params
 * @param {import("discourse/services/store").default} params.store
 * @param {import("discourse/models/user").default | null} params.currentUser
 * @param {string} params.filterType — one of "latest" | "top" | "hot" | "new" | "unread"
 * @param {number} [params.categoryId]
 * @param {string} [params.tag]
 * @param {boolean} [params.solved]
 * @param {number} [params.count=5]
 * @returns {Promise<Array<import("discourse/models/topic").default> | null>}
 */
export async function fetchTopicList({
  store,
  currentUser,
  filterType,
  categoryId,
  tag,
  solved,
  count = 5,
}) {
  if (USER_ONLY_FILTERS.has(filterType) && !currentUser) {
    return null;
  }

  const filter = buildFilterPath(filterType, categoryId, tag);
  const requestParams = solved ? { solved } : {};

  // `ignoreUnsent: false` so a failed request (including offline) rejects
  // rather than hanging unsettled — the block's loading boundary then surfaces
  // the error instead of showing the skeleton or stale data forever.
  const topicList = await store.findFiltered(
    "topicList",
    { filter, params: requestParams },
    { ignoreUnsent: false }
  );

  if (!topicList?.topics?.length) {
    return null;
  }

  return topicList.topics.slice(0, count);
}

export const VALID_TOPIC_LIST_FILTERS = [
  "latest",
  "top",
  "hot",
  "new",
  "unread",
];
