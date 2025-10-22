import NotificationsTracking from "discourse/components/notifications-tracking";

const GroupNotificationsTracking = <template>
  <NotificationsTracking
    @onChange={{@onChange}}
    @levelId={{@levelId}}
    @showCaret={{false}}
    @showFullTitle={{false}}
    @prefix="groups.notifications"
    class="group-notifications-tracking"
  />
</template>;

export default GroupNotificationsTracking;
