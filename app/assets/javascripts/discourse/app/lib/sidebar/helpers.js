import Category from "discourse/models/category";

export function canDisplayCategory(categoryId, siteSettings) {
  if (siteSettings.allow_uncategorized_topics) {
    return true;
  }

  return !Category.isUncategorized(categoryId);
}

export function hasDefaultSidebarCategories(siteSettings) {
  return siteSettings.default_navigation_menu_categories.length > 0;
}

export function hasDefaultSidebarTags(siteSettings) {
  return siteSettings.default_navigation_menu_tags.length > 0;
}
