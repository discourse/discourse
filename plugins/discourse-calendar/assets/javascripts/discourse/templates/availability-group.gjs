import TeamAvailabilityCalendar from "../components/team-availability-calendar";

export default <template>
  <div class="team-availability-page">
    <TeamAvailabilityCalendar @groupName={{@model.groupName}} />
  </div>
</template>
