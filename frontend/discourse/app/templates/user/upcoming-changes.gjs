import UserUpcomingChanges from "discourse/components/user-upcoming-changes";

export default <template>
  <UserUpcomingChanges
    @upcomingChangeStats={{@controller.model.upcoming_changes_stats}}
  />
</template>
