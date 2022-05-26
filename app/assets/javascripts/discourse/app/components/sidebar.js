import { cached } from "@glimmer/tracking";

import GlimmerComponent from "discourse/components/glimmer";
import { NotificationLevels } from "discourse/lib/notification-levels";

export default class Sidebar extends GlimmerComponent {
  @cached
  get trackedCategories() {
    const categories = [];

    this.site.categoriesList.forEach((category) => {
      if (
        (category.id === this.siteSettings.uncategorized_category_id &&
          this.siteSettings.suppress_uncategorized_badge) ||
        category.notification_level < NotificationLevels.TRACKING
      ) {
        return;
      }

      categories.push(category);
    });

    return categories;
  }
}
