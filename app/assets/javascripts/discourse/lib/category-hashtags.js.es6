import Category from 'discourse/models/category';
import { categoryBadgeHTML } from 'discourse/helpers/category-link';

export const SEPARATOR = ":";

export function findCategoryByHashtagSlug(hashtagSlug) {
  if (hashtagSlug.indexOf('#') === 0) hashtagSlug = hashtagSlug.slice(1);
  return Category.findBySlug.apply(null, hashtagSlug.split(SEPARATOR, 2).reverse());
};

export function replaceSpan($elem, categorySlug, categoryLink) {
  const category = findCategoryByHashtagSlug(categorySlug);

  if (!category) {
    $elem.replaceWith(categorySlug);
  } else {
    $elem.replaceWith(categoryBadgeHTML(
      category, { url: categoryLink, allowUncategorized: true }
    ));
  }
};

export function decorateLinks($elems) {
  $elems.each((_, elem) => replaceSpan($(elem), elem.text, elem.href));
}

