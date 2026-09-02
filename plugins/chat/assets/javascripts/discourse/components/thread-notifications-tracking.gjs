import NotificationsTracking from "discourse/components/notifications-tracking";
import { threadNotificationButtonLevels } from "discourse/plugins/chat/discourse/lib/chat-notification-levels";

const ThreadNotificationsTracking = <template>
  <NotificationsTracking
    class="thread-notifications-tracking"
    @levelId={{@levelId}}
    @levels={{threadNotificationButtonLevels}}
    @onChange={{@onChange}}
    @prefix="chat.thread.notifications"
    @showCaret={{false}}
    @showFullTitle={{false}}
    @triggerClass="btn-transparent"
  />
</template>;

export default ThreadNotificationsTracking;
