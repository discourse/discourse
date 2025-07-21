import Component from "@glimmer/component";
import CategoryCalendar from "../../components/category-calendar";

export default class CategoryEventsCalendar extends Component {
  static shouldRender(_, ctx) {
    return (
      ctx.siteSettings.calendar_categories_outlet ===
      "discovery-list-container-top"
    );
  }

  <template><CategoryCalendar /></template>
}
