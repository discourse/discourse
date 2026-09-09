import NotificationsTracking from "discourse/components/notifications-tracking";

const TagNotificationsTracking = <template>
  <NotificationsTracking
    class="tag-notifications-tracking"
    @levelId={{@levelId}}
    @onChange={{@onChange}}
    @prefix="tagging.notifications"
    @showCaret={{false}}
    @showFullTitle={{false}}
  />
</template>;

export default TagNotificationsTracking;
