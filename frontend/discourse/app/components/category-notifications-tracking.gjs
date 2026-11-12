import NotificationsTracking from "discourse/components/notifications-tracking";
import { i18n } from "discourse-i18n";

const CategoryNotificationsTracking = <template>
  <NotificationsTracking
    class="category-notifications-tracking"
    @levelId={{@levelId}}
    @onChange={{@onChange}}
    @prefix="category.notifications"
    @showCaret={{@showCaret}}
    @showFullTitle={{@showFullTitle}}
    @title={{i18n "category.notifications.title"}}
  />
</template>;

export default CategoryNotificationsTracking;
