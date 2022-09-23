export function canDisplayCategory(category, siteSettings) {
  if (siteSettings.allow_uncategorized_topics) {
    return true;
  }

  return !category.isUncategorizedCategory;
}
