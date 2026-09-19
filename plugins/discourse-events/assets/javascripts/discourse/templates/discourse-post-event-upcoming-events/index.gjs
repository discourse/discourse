import UpcomingEventsCalendar from "../../components/upcoming-events-calendar";

export default <template>
  <div class="discourse-post-event-upcoming-events">
    <UpcomingEventsCalendar
      @initialDate={{@controller.initialDate}}
      @initialView={{@controller.initialView}}
    />
  </div>
</template>
