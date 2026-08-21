import { applyValueTransformer } from "discourse/lib/transformer";

/**
 * The subcategories to display for a category in the category list layouts.
 *
 * Consumers of the `category-list-subcategories` transformer can return a
 * shorter list, or `[]`, to collapse deeper levels of the list without
 * affecting `Category#subcategories`, which other surfaces rely on.
 *
 * @param {Category} category the category whose children are being listed
 * @param {Object} [options]
 * @param {string} [options.surface] where the list is being rendered:
 *   `"subcategory_list"` when it sits inside a single category's topic list,
 *   otherwise `undefined` for the global categories page
 * @param {Category[]} [options.subcategories] the children to transform, for
 *   layouts which don't source them from `category.subcategories`
 * @returns {Category[]} the subcategories to render
 */
export default function categoryListSubcategories(
  category,
  { surface, subcategories } = {}
) {
  return (
    applyValueTransformer(
      "category-list-subcategories",
      subcategories ?? category?.subcategories ?? [],
      { category, surface }
    ) ?? []
  );
}

/**
 * Whether any of the given subcategories has children of its own, meaning the
 * list needs the grandparent layout rather than plain subcategory links.
 *
 * @param {Category[]} subcategories the subcategories being rendered
 * @param {Object} [options] the options passed to `categoryListSubcategories`
 * @returns {boolean}
 */
export function hasGrandchildren(subcategories, options) {
  return subcategories.some(
    (subcategory) => categoryListSubcategories(subcategory, options).length > 0
  );
}
