import NotificationsTracking from "discourse/components/notifications-tracking";
import { topicLevels } from "discourse/lib/notification-levels";
import { i18n } from "discourse-i18n";

const TopicNotificationsTracking = <template>
  <NotificationsTracking
    @onChange={{@onChange}}
    @levelId={{@levelId}}
    @showCaret={{@showCaret}}
    @showFullTitle={{@showFullTitle}}
    @prefix="topic.notifications"
    @title={{i18n "topic.notifications.title"}}
    class="topic-notifications-tracking"
    @levels={{topicLevels}}
  />
</template>;

export default TopicNotificationsTracking;
