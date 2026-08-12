import UpcomingEventsCalendar from "../../components/upcoming-events-calendar";

export default <template>
  <div class="discourse-post-event-upcoming-events">
    <UpcomingEventsCalendar
      @mine={{true}}
      @initialView={{@controller.initialView}}
      @initialDate={{@controller.initialDate}}
    />
  </div>
</template>
