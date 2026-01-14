import Component from "@glimmer/component";
import CategoryCalendar from "../../components/category-calendar";

export default class CategoryEventsCalendar extends Component {
  static shouldRender(_, ctx) {
    return (
      ctx.siteSettings.calendar_categories_outlet === "before-topic-list-body"
    );
  }

  <template>
    <div
      id="category-events-calendar"
      class="--before-topic-list-body"
    ><CategoryCalendar /></div>
  </template>
}
