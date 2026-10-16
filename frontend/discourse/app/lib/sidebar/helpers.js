import Category from "discourse/models/category";

/**
 * @typedef {object} SidebarUrlData
 * @property {number} id
 * @property {string} name
 * @property {string} value
 * @property {string} icon
 * @property {boolean} external
 * @property {string} segment
 * @property {string | null} locale
 * @property {boolean} [can_localize]
 * @property {Array<{ id: number, sidebar_url_id: number, locale: string, name: string }>} [localizations]
 * @typedef {object} SidebarSectionData
 * @property {number} id
 * @property {string} title
 * @property {SidebarUrlData[]} links
 * @property {string} slug
 * @property {boolean} public
 * @property {"community" | null} section_type
 * @property {string | null} locale
 * @property {Array<{ id: number, sidebar_section_id: number, locale: string, title: string }>} [localizations]
 */
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

export function getSidebarSectionContentId(name) {
  return `sidebar-section-content-${name}`;
}

export function getCollapsedSidebarSectionKey(name) {
  return `sidebar-section-${name}-collapsed`;
}

/**
 * Replaces freshly-changed sections in the user's list, the same way the edit
 * form applies its save, so the sidebar re-renders from them.
 *
 * @param {User} user - The current user holding `sidebar_sections`.
 * @param {SidebarSectionData[]} updatedSections - Serialized sections to swap in by id.
 */
export function replaceUserSidebarSections(user, updatedSections) {
  const sections = user.sidebar_sections.map((section) => {
    return updatedSections.find((fresh) => fresh.id === section.id) ?? section;
  });
  user.set("sidebar_sections", sections);
}
