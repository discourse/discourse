import NotificationsTracking from "discourse/components/notifications-tracking";
import { i18n } from "discourse-i18n";

const CategoryNotificationsTracking = <template>
  <NotificationsTracking
    @onChange={{@onChange}}
    @levelId={{@levelId}}
    @showCaret={{@showCaret}}
    @showFullTitle={{@showFullTitle}}
    @prefix="category.notifications"
    @title={{i18n "category.notifications.title"}}
    class="category-notifications-tracking"
  />
</template>;

export default CategoryNotificationsTracking;
