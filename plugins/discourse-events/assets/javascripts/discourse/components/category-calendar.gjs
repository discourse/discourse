import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import formatEventForCalendar from "../lib/format-event-for-calendar";
import openEventComposer from "../lib/open-event-composer";
import FullCalendar from "./full-calendar";

export default class CategoryCalendar extends Component {
  @service composer;
  @service currentUser;
  @service router;
  @service siteSettings;
  @service discoursePostEventService;

  get canCreateEvent() {
    if (!this.currentUser) {
      return false;
    }

    return (
      this.currentUser.can_create_discourse_post_event &&
      this.currentUser.can_create_topic &&
      this.category?.canCreateTopic
    );
  }

  get includeSubcategories() {
    return !this.router.currentRoute?.attributes?.noSubcategories;
  }

  get refreshKey() {
    return JSON.stringify([
      this.category.id,
      this.includeSubcategories,
      this.tags,
      this.noTags,
    ]);
  }

  get shouldRender() {
    if (!this.siteSettings.discourse_post_event_enabled) {
      return false;
    }

    if (this.siteSettings.login_required && !this.currentUser) {
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
    return !!this.calendarCategory;
  }

  get category() {
    return this.router.currentRoute?.attributes?.category;
  }

  get tags() {
    const { tag, additionalTags = [] } =
      this.router.currentRoute?.attributes || {};
    return tag && !this.noTags ? [tag.name, ...additionalTags] : [];
  }

  get noTags() {
    const tag = this.router.currentRoute?.attributes?.tag;
    return tag?.slug === "none" && !tag.id;
  }

  get calendarCategory() {
    const categoryIds = [
      ...this.siteSettings.events_calendar_categories.split("|"),
      ...this.categorySettings.map((item) => item.categoryId),
    ];
    let category = this.category;
    while (category) {
      if (categoryIds.includes(category.id.toString())) {
        return category;
      }
      category = category.parentCategory;
    }
  }

  get renderWeekends() {
    return this.categorySetting?.weekends !== "false";
  }

  get categorySettings() {
    return this.siteSettings.calendar_categories
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
  }

  get categorySetting() {
    return this.categorySettings.find(
      (item) => item.categoryId === this.calendarCategory?.id.toString()
    );
  }

  @action
  async onDateClick(info) {
    await openEventComposer({
      composer: this.composer,
      currentUser: this.currentUser,
      siteSettings: this.siteSettings,
      info,
      category: this.category,
    });
  }

  @bind
  async loadEvents(info) {
    try {
      const params = {
        after: info.startStr,
        before: info.endStr,
        include_ongoing: true,
        category_id: this.category.id,
      };

      if (this.includeSubcategories) {
        params.include_subcategories = true;
      }

      if (this.noTags) {
        params.no_tags = true;
      } else if (this.tags.length) {
        params.tags = this.tags;
      }

      const events = await this.discoursePostEventService.fetchEvents(params);
      return this.formattedEvents(events);
    } catch (error) {
      popupAjaxError(error);
    }
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
        @height="650px"
        @initialView={{this.categorySetting.defaultView}}
        @onDateClick={{if this.canCreateEvent this.onDateClick}}
        @onLoadEvents={{this.loadEvents}}
        @refreshKey={{this.refreshKey}}
        @weekends={{this.renderWeekends}}
      />
    {{/if}}
  </template>
}
