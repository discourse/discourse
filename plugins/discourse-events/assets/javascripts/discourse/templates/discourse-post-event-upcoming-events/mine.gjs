import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import UpcomingEventsCalendar from "../../components/upcoming-events-calendar.gjs";

export default <template>
  <div
    class={{dConcatClass
      "discourse-post-event-upcoming-events"
      (if (eq @controller.initialView "year") "--agenda")
    }}
  >
    <UpcomingEventsCalendar
      @initialDate={{@controller.initialDate}}
      @initialView={{@controller.initialView}}
      @mine={{true}}
    />
  </div>
</template>
