import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import UpcomingEventsCalendar from "../../components/upcoming-events-calendar.gjs";

export default <template>
  <div
    class={{dConcatClass
      "discourse-post-event-upcoming-events"
      (if
        (or
          (eq @controller.initialView "year")
          (eq @controller.initialView "listYear")
          (eq @controller.initialView "listNextYear")
        )
        "--agenda"
      )
    }}
  >
    <UpcomingEventsCalendar
      @initialDate={{@controller.initialDate}}
      @initialView={{@controller.initialView}}
    />
  </div>
</template>
