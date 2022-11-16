import Category from "discourse/models/category";

export function canDisplayCategory(categoryId, siteSettings) {
  if (siteSettings.allow_uncategorized_topics) {
    return true;
  }

  return !Category.isUncategorized(categoryId);
}
