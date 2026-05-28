import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import Category from "discourse/models/category";
import formatEventForCalendar from "../lib/format-event-for-calendar";
import FullCalendar from "./full-calendar";

export default class CategoryCalendar extends Component {
  @service currentUser;
  @service router;
  @service siteSettings;
  @service discoursePostEventService;

  @bind
  async loadEvents(info) {
    try {
      const params = {
        after: info.startStr,
        before: info.endStr,
        include_ongoing: true,
        category_id: this.category.id,
        include_subcategories: true,
      };

      const events = await this.discoursePostEventService.fetchEvents(params);
      return this.formattedEvents(events);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  get shouldRender() {
    if (!this.siteSettings.discourse_post_event_enabled) {
      return false;
    }

    if (this.siteSettings.login_required && !this.currentUser) {
      return false;
    }

    if (!this.router.currentRoute?.params?.category_slug_path_with_id) {
      return false;
    }

    if (!this.category) {
      return false;
    }

    if (!this.validCategory) {
      return false;
    }

    return true;
  }

  get validCategory() {
    if (
      !this.categorySetting &&
      !this.siteSettings.events_calendar_categories
    ) {
      return false;
    }

    return (
      this.categorySetting?.categoryId === this.category.id.toString() ||
      this.siteSettings.events_calendar_categories
        .split("|")
        .filter(Boolean)
        .includes(this.category.id.toString())
    );
  }

  get category() {
    return Category.findBySlugPathWithID(
      this.router.currentRoute.params.category_slug_path_with_id
    );
  }

  get renderWeekends() {
    return this.categorySetting?.weekends !== "false";
  }

  get categorySetting() {
    const settings = this.siteSettings.calendar_categories
      .split("|")
      .filter(Boolean)
      .map((stringSetting) => {
        const data = {};
        stringSetting
          .split(";")
          .filter(Boolean)
          .forEach((s) => {
            const parts = s.split("=");
            data[parts[0]] = parts[1];
          });
        return data;
      });

    return settings.find(
      (item) => item.categoryId === this.category.id.toString()
    );
  }

  @action
  formattedEvents(events = []) {
    const timezone = this.currentUser?.user_option?.timezone;
    return events.map((event) =>
      formatEventForCalendar(
        event,
        this.siteSettings.map_events_to_color,
        timezone
      )
    );
  }

  <template>
    {{#if this.shouldRender}}
      <FullCalendar
        @onLoadEvents={{this.loadEvents}}
        @height="650px"
        @initialView={{this.categorySetting.defaultView}}
        @weekends={{this.renderWeekends}}
        @refreshKey={{this.category.id}}
      />
    {{/if}}
  </template>
}
