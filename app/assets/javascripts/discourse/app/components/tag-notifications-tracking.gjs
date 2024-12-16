import NotificationsTracking from "discourse/components/notifications-tracking";

const TagNotificationsTracking = <template>
  <NotificationsTracking
    @onChange={{@onChange}}
    @levelId={{@levelId}}
    @showCaret={{false}}
    @showFullTitle={{false}}
    @prefix="tagging.notifications"
    class="tag-notifications-tracking"
  />
</template>;

export default TagNotificationsTracking;
