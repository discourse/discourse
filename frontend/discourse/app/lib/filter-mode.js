import Category from "discourse/models/category";

export function calculateFilterMode({ category, filterType, noSubcategories }) {
  if (category) {
    return `c/${Category.slugFor(category)}${
      noSubcategories ? "/none" : ""
    }/l/${filterType}`;
  } else {
    return filterType;
  }
}

export function filterTypeForMode(mode) {
  return mode?.split("/").pop();
}

/**
 * The `filter` the server reports for a client-side filter mode, or `undefined`
 * when it cannot be derived from the mode alone — user, group, private message
 * and tag intersection lists end in a name rather than a filter.
 *
 * @param {string} mode a filter mode, e.g. `latest` or `c/bug/1/none/l/votes`
 * @returns {string|undefined} the matching `TopicList#filter`
 */
export function serverFilterForMode(mode) {
  if (!mode) {
    return;
  }

  const segments = mode.split("/");
  const listIndex = segments.lastIndexOf("l");

  if (listIndex !== -1) {
    return segments[listIndex + 1];
  }

  if (segments.length === 1) {
    return mode;
  }
}
