import Site from "discourse/models/site";
import User from "discourse/models/user";

export const TRACKED_QUERY_PARAM_VALUE = "tracked";

export function hasTrackedFilter(queryParams) {
  if (!queryParams) {
    return false;
  }

  return (
    queryParams.f === TRACKED_QUERY_PARAM_VALUE ||
    queryParams.filter === TRACKED_QUERY_PARAM_VALUE
  );
}

/**
 * Logic here needs to be in sync with `TopicQuery#tracked_filter` on the server side. See `TopicQuery#tracked_filter`
 * for the rational behind this decision.
 */
export function isTrackedTopic(topic) {
  if (topic.category_id) {
    const categories = Site.current().trackedCategoriesList;

    for (const category of categories) {
      if (category.id === topic.category_id) {
        return true;
      }

      if (
        category.subcategories &&
        category.subcategories.some((subCategory) => {
          if (subCategory.id === topic.category_id) {
            return true;
          }

          if (
            subCategory.subcategories &&
            subCategory.subcategories.some((c) => {
              return c.id === topic.category_id;
            })
          ) {
            return true;
          }
        })
      ) {
        return true;
      }
    }
  }

  if (topic.tags) {
    const tags = User.current().trackedTags;

    for (const tag of tags) {
      if (topic.tags.includes(tag)) {
        return true;
      }
    }
  }

  return false;
}
