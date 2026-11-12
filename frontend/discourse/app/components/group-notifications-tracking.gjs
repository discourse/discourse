import NotificationsTracking from "discourse/components/notifications-tracking";

const GroupNotificationsTracking = <template>
  <NotificationsTracking
    class="group-notifications-tracking"
    @levelId={{@levelId}}
    @onChange={{@onChange}}
    @prefix="groups.notifications"
    @showCaret={{false}}
    @showFullTitle={{false}}
  />
</template>;

export default GroupNotificationsTracking;
