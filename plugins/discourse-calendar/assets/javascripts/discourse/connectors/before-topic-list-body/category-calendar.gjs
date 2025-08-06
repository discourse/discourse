import Component from "@glimmer/component";

export default class CategoryCalendar extends Component {
  static shouldRender(_, ctx) {
    return (
      ctx.siteSettings.calendar_categories_outlet === "before-topic-list-body"
    );
  }

  <template>
    <div class="before-topic-list-body-outlet category-calendar"></div>
  </template>
}
