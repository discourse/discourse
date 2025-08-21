import { array } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import UpcomingEventsCalendar from "../components/upcoming-events-calendar";

export default RouteTemplate(
  <template>
    <div class="discourse-post-event-upcoming-events">
      {{#each (array @model) as |model|}}
        <UpcomingEventsCalendar @events={{model}} @view={{@controller.view}} />
      {{/each}}
    </div>
  </template>
);
