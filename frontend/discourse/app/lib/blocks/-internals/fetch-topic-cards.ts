import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";
import type Site from "discourse/models/site";
import { categoryBadgeHTML } from "discourse/ui-kit/helpers/d-category-link";

/**
 * The list endpoint validates `per_page` as 1..100, and defaults to a page size
 * well below that, so ids are requested in chunks of this size with an explicit
 * `per_page`. Anything larger would be silently truncated to the default page.
 */
const MAX_TOPIC_IDS_PER_REQUEST = 100;

/** The card-facing projection of a single topic. */
export interface TopicCardData {
  /** The topic id. */
  id: number;

  /** The linked topic URL. */
  url: string;

  /** Plain title, for the stretched link's accessible name. */
  title: string;

  /** HTML fancy title, rendered visibly. */
  fancyTitle: string;

  /** Pre-rendered, non-link category badge HTML, or `null` when uncategorized. */
  categoryBadge: string | null;

  /** The topic's own image URL, or `null` when none. */
  imageUrl: string | null;

  /** The server-rendered excerpt HTML, or `null` when the topic has none. */
  excerpt: string | null;
}

/** A topic as the list endpoint serializes it, narrowed to the fields a card reads. */
interface ListTopic {
  id: number;
  slug?: string;
  title: string;
  fancy_title: string;
  category_id?: number | null;
  image_url?: string | null;
  excerpt?: string | null;
}

/** The shape of the list endpoint's payload, narrowed to what a card reads. */
interface TopicListResponse {
  topic_list?: {
    topics?: ListTopic[];

    /** Present only when the site lazy-loads categories. */
    categories?: object[];
  };
}

/**
 * The promise `ajax` returns. It predates `AbortSignal`, and instead exposes an
 * `abort()` that cancels the underlying request.
 */
type AbortablePromise<T> = Promise<T> & { abort: () => void };

/** Parameters for {@link fetchTopicCards}. */
export interface FetchTopicCardsParams {
  /** The topic ids to resolve. */
  topicIds: number[];

  /** The site, used to register categories the payload side-loads. */
  site: Site;

  /** Cancels the in-flight requests when the caller is superseded. */
  signal?: AbortSignal;
}

/**
 * Splits a list into consecutive chunks of at most `size` entries.
 *
 * @param values - The values to split.
 * @param size - The maximum number of entries per chunk.
 * @returns The chunks, in order.
 */
function chunk<T>(values: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let index = 0; index < values.length; index += size) {
    chunks.push(values.slice(index, index + size));
  }
  return chunks;
}

/**
 * Requests one chunk of topics from the list endpoint.
 *
 * Talks to the endpoint directly rather than going through the topic-list store
 * adapter: that adapter answers its first call from the preload store, which
 * would hand these cards whatever list the server inlined for the page instead
 * of the topics they asked for.
 *
 * @param topicIds - The ids to request (already within the per-request cap).
 * @param signal - Cancels the request when the caller is superseded.
 * @returns The raw list payload.
 */
function requestTopics(
  topicIds: number[],
  signal?: AbortSignal
): Promise<TopicListResponse> {
  // `ignoreUnsent: false` so a failed request (including offline) rejects rather
  // than hanging unsettled — the block's loading boundary then surfaces the
  // error instead of showing the skeleton forever.
  const request = ajax("/latest.json", {
    data: {
      topic_ids: topicIds.join(","),
      include_excerpts: true,
      per_page: topicIds.length,
    },
    ignoreUnsent: false,
  }) as AbortablePromise<TopicListResponse>;

  signal?.addEventListener("abort", () => request.abort(), { once: true });

  return request;
}

/**
 * Projects one serialized topic into the fields a card renders.
 *
 * @param topic - The topic as the list endpoint serialized it.
 * @returns The card-facing projection.
 */
function projectCard(topic: ListTopic): TopicCardData {
  const category = topic.category_id
    ? Category.findById(topic.category_id)
    : null;

  return {
    id: topic.id,
    url: `/t/${topic.slug ?? "topic"}/${topic.id}`,
    // Plain title for the stretched link's accessible name; `fancyTitle` (HTML)
    // is what renders visibly.
    title: topic.title,
    fancyTitle: topic.fancy_title,
    // Pre-rendered, non-link badge: the whole card is the link, so an inner
    // category link would nest anchors. `link: false` yields a plain badge.
    categoryBadge: category
      ? categoryBadgeHTML(category, { link: false, allowUncategorized: true })
      : null,
    imageUrl: topic.image_url || null,
    excerpt: topic.excerpt || null,
  };
}

/**
 * Resolves the card-facing data for a set of topics in one request, keyed by
 * topic id. Asks the list endpoint to serialize excerpts, which it otherwise
 * omits unless the site opts every list into them.
 *
 * Ids the response doesn't carry are simply absent from the returned map: the
 * endpoint drops topics the viewer can't see, and callers decide what an
 * unresolved topic means for them.
 *
 * @param params - The topics to resolve, the site, and a cancellation signal.
 * @returns The resolved cards, keyed by topic id.
 */
export async function fetchTopicCards({
  topicIds,
  site,
  signal,
}: FetchTopicCardsParams): Promise<Map<number, TopicCardData>> {
  const responses = await Promise.all(
    chunk(topicIds, MAX_TOPIC_IDS_PER_REQUEST).map((ids) =>
      requestTopics(ids, signal)
    )
  );

  const cards = new Map<number, TopicCardData>();

  for (const response of responses) {
    // Register side-loaded categories before projecting, so the badge lookup
    // resolves on sites that lazy-load them.
    response.topic_list?.categories?.forEach((category) =>
      site.updateCategory(category)
    );

    response.topic_list?.topics?.forEach((topic) =>
      cards.set(topic.id, projectCard(topic))
    );
  }

  return cards;
}
