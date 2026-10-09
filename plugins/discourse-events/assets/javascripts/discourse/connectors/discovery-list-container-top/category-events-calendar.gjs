import Component from "@glimmer/component";
import { service } from "@ember/service";
import CategoryCalendar from "../../components/category-calendar";

export default class CategoryEventsCalendar extends Component {
  static shouldRender(_, ctx) {
    return ["discovery-list-container-top", "before-topic-list-body"].includes(
      ctx.siteSettings.calendar_categories_outlet
    );
  }

  @service router;

  @service siteSettings;

  get showCalendar() {
    return (
      this.siteSettings.calendar_categories_outlet ===
        "discovery-list-container-top" ||
      !this.router.currentRoute?.attributes?.list?.topics?.length
    );
  }

  <template>
    {{#if this.showCalendar}}
      <div
        class="--discovery-list-container-top"
        id="category-events-calendar"
      ><CategoryCalendar /></div>
    {{/if}}
  </template>
}
