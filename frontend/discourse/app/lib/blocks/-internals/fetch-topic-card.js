// @ts-check
import Category from "discourse/models/category";
import Topic from "discourse/models/topic";
import { categoryBadgeHTML } from "discourse/ui-kit/helpers/d-category-link";

const EXCERPT_MAX_LENGTH = 300;

/**
 * Strips a post's cooked HTML down to a plain-text excerpt. The topic-view
 * payload (`/t/:id.json`) carries no top-level `excerpt` field — that lives on
 * the topic-list serializer — so the card derives one from the first post's
 * cooked body, mirroring how excerpts are produced elsewhere.
 *
 * @param {string|undefined} cooked - The first post's cooked HTML.
 * @param {number} [maxLength] - Maximum excerpt length before truncation.
 * @returns {string|null} The plain-text excerpt, or `null` when empty.
 */
function extractExcerpt(cooked, maxLength = EXCERPT_MAX_LENGTH) {
  if (!cooked) {
    return null;
  }

  const div = document.createElement("div");
  div.innerHTML = cooked;
  const text = div.textContent?.trim();

  if (!text) {
    return null;
  }

  return text.length > maxLength ? `${text.slice(0, maxLength)}…` : text;
}

/**
 * Resolves the card-facing data for a single topic by id. Fetches the topic
 * view (`/t/:id.json`) and projects just the fields a card renders: the linked
 * URL, the fancy title, the resolved category, the topic's own image, and a
 * plain-text excerpt derived from the first post.
 *
 * @param {Object} options
 * @param {number} options.topicId - The id of the topic to resolve.
 * @returns {Promise<Object|null>} The card data, or `null` when no `topicId` is
 *   configured.
 * @throws When a configured topic can't be resolved (fetch failure, or the
 *   fetch returns no valid topic).
 */
export async function fetchTopicCard({ topicId }) {
  if (!topicId) {
    return null;
  }

  // Don't catch: a configured topic that can't load is an error (the error
  // slot), not an empty card.
  const topic = await Topic.find(topicId, {});

  if (!topic?.id) {
    throw new Error(`No topic found for id ${topicId}`);
  }

  const firstPost = topic.post_stream?.posts?.[0];
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
    excerpt: extractExcerpt(firstPost?.cooked),
  };
}
