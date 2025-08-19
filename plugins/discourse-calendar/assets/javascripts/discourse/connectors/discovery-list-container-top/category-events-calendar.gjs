import Component from "@glimmer/component";

export default class CategoryEventsCalendar extends Component {
  static shouldRender(_, ctx) {
    return (
      ctx.siteSettings.calendar_categories_outlet ===
      "discovery-list-container-top"
    );
  }

  <template>
    <div id="category-events-calendar"></div>
  </template>
}
