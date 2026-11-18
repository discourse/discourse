/**
 * The ids of the categories configured to hold events.
 *
 * @param {object} siteSettings - The site settings service.
 * @returns {number[]}
 */
export function eventsCategoryIds(siteSettings) {
  return (siteSettings.events_calendar_categories || "")
    .split("|")
    .filter(Boolean)
    .map((id) => parseInt(id, 10));
}

/**
 * Whether the upcoming events block needs a category choice: with a single
 * events category there is nothing to pick between.
 *
 * @param {object} siteSettings - The site settings service.
 * @returns {boolean}
 */
export function offersCategoryChoice(siteSettings) {
  return eventsCategoryIds(siteSettings).length !== 1;
}

/**
 * Whether the category the block is pointed at has a subcategory worth
 * including. The block is pointed at the chosen category, or at the only events
 * category when there is just one. When events categories are configured, a
 * subcategory only counts if it is one of them too.
 *
 * @param {object} context
 * @param {object} context.args - The block's current args.
 * @param {object} context.siteSettings - The site settings service.
 * @param {object} context.site - The site service.
 * @returns {boolean}
 */
export function hasEventsSubcategories({ args, siteSettings, site }) {
  const eventsIds = eventsCategoryIds(siteSettings);
  const targetId =
    args.categoryId ?? (eventsIds.length === 1 ? eventsIds[0] : null);
  if (!targetId) {
    return false;
  }

  const categories = site.categories ?? [];
  const descendants = [];
  const queue = [targetId];
  while (queue.length) {
    const parentId = queue.shift();
    for (const category of categories) {
      if (category.parent_category_id === parentId) {
        descendants.push(category.id);
        queue.push(category.id);
      }
    }
  }

  return eventsIds.length
    ? descendants.some((id) => eventsIds.includes(id))
    : descendants.length > 0;
}
