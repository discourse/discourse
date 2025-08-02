import NotificationsTracking from "discourse/components/notifications-tracking";
import { threadNotificationButtonLevels } from "discourse/plugins/chat/discourse/lib/chat-notification-levels";

const ThreadNotificationsTracking = <template>
  <NotificationsTracking
    @onChange={{@onChange}}
    @levels={{threadNotificationButtonLevels}}
    @levelId={{@levelId}}
    @showCaret={{false}}
    @showFullTitle={{false}}
    @prefix="chat.thread.notifications"
    class="thread-notifications-tracking"
    @triggerClass="btn-transparent"
  />
</template>;

export default ThreadNotificationsTracking;
