import Category from "discourse/models/category";
import type Topic from "discourse/models/topic";
import type User from "discourse/models/user";
import type Store from "discourse/services/store";

const USER_ONLY_FILTERS = new Set(["new", "unread"]);

/**
 * Builds the topic-list filter path for a filter type combined with an
 * optional category and tag. Mirrors core's URL conventions so
 * `store.findFiltered` resolves to the right endpoint.
 *
 * @param filterType - The filter type (e.g. "latest").
 * @param categoryId - An optional category to scope to.
 * @param tag - An optional tag to scope to.
 * @returns The filter path.
 */
function buildFilterPath(
  filterType: string,
  categoryId?: number,
  tag?: string
): string {
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

/** Parameters for {@link fetchTopicList}. */
interface FetchTopicListParams {
  /** The store service used to load topics. */
  store: Store;

  /** The signed-in user, or `null` when anonymous. */
  currentUser: User | null;

  /** The filter type: one of "latest", "top", "hot", "new", or "unread". */
  filterType: string;

  /** An optional category to scope the list to. */
  categoryId?: number;

  /** An optional tag to scope the list to. */
  tag?: string;

  /** Whether to restrict the list to solved topics. */
  solved?: boolean;

  /** Maximum number of topics to resolve. */
  count?: number;
}

/**
 * Shared topic-list fetcher used by topic-rendering blocks. Resolves to
 * the first `count` topics matching the supplied filter, or `null` when
 * the list is empty or the filter requires a signed-in user that the
 * caller doesn't have.
 *
 * @param params - The fetch parameters.
 * @returns The resolved topics, or `null` when the list is empty or a
 *   signed-in user is required but absent.
 */
export async function fetchTopicList({
  store,
  currentUser,
  filterType,
  categoryId,
  tag,
  solved,
  count = 5,
}: FetchTopicListParams): Promise<Topic[] | null> {
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
