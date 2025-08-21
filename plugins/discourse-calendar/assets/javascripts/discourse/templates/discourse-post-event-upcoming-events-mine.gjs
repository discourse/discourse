import RouteTemplate from "ember-route-template";
import UpcomingEventsCalendar from "../components/upcoming-events-calendar";

export default RouteTemplate(
  <template>
    <div class="discourse-post-event-upcoming-events">
      <UpcomingEventsCalendar
        @events={{@model}}
        @mine={{true}}
        @view={{@controller.view}}
      />
    </div>
  </template>
);
