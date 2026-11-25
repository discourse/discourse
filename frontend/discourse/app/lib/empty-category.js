import { filterTypeForMode } from "discourse/lib/filter-mode";

/**
 * Whether a category's latest list has no conversations yet. The category's own
 * "About" topic and topics started by system or bot accounts (ids <= 0) don't
 * count.
 *
 * @param {object} options
 * @param {object} options.category - The category being viewed.
 * @param {object} [options.tag] - The tag filter, if any.
 * @param {object} options.list - The loaded topic list.
 * @returns {boolean}
 */
export function isEmptyCategoryList({ category, tag, list }) {
  if (
    !category ||
    tag ||
    !list ||
    filterTypeForMode(list.filter) !== "latest" ||
    list.more_topics_url
  ) {
    return false;
  }

  const aboutTopicId = Number(category.topic_url?.split("/").pop());

  // The server lists the original poster first in `posters`.
  return (list.topics ?? []).every(
    (topic) => topic.id === aboutTopicId || topic.posters?.[0]?.user?.id <= 0
  );
}
