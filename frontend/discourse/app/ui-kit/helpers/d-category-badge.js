import { isPresent } from "@ember/utils";
import { categoryLinkHTML } from "discourse/ui-kit/helpers/d-category-link";

/**
 * Renders a category badge.
 *
 * `topicCount`, `subcategoryCount`, `readOnly` and `ancestors` are what a picker row needs to
 * match the badge core renders in its own category list; the count carries its own `aria-label`
 * so it does not read as a bare number beside the name.
 *
 * @param {object} cat - the category.
 * @param {object} [options]
 * @param {boolean} [options.hideParent] - omit the parent badge.
 * @param {boolean} [options.allowUncategorized] - render the uncategorized category.
 * @param {string} [options.styleType] - "square" (default), "icon" or "emoji".
 * @param {string} [options.icon] - icon id, when styleType is "icon".
 * @param {string} [options.emoji] - emoji name, when styleType is "emoji".
 * @param {boolean} [options.previewColor] - apply the colour as an inline style.
 * @param {boolean|string} [options.link] - link the badge. Defaults to false.
 * @param {Array} [options.ancestors] - ancestor categories, rendered outermost first. Only the
 *   category itself keeps `topicCount` and `readOnly`.
 * @param {number} [options.topicCount] - topics in the category.
 * @param {number} [options.subcategoryCount] - subcategories to note alongside the badge.
 * @param {boolean} [options.readOnly] - mark the category as one that cannot be posted in.
 */
export default function dCategoryBadge(cat, options = {}) {
  return categoryLinkHTML(cat, {
    hideParent: options.hideParent,
    allowUncategorized: options.allowUncategorized,
    categoryStyle: options.categoryStyle,
    styleType: options.styleType,
    icon: options.icon,
    emoji: options.emoji,
    previewColor: options.previewColor,
    ancestors: options.ancestors,
    topicCount: options.topicCount,
    subcategoryCount: options.subcategoryCount,
    readOnly: options.readOnly,
    link: isPresent(options.link) ? options.link : false,
  });
}
