import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import Category from "discourse/models/category";
import { formatEventName } from "../helpers/format-event-name";
import { isNotFullDayEvent } from "../lib/guess-best-date-format";
import FullCalendar from "./full-calendar";

export default class CategoryCalendar extends Component {
  @service currentUser;
  @service router;
  @service siteSettings;
  @service store;
  @service discoursePostEventApi;

  @bind
  async loadEvents() {
    try {
      const params = {
        post_id: this.categorySetting?.postId,
        category_id: this.category.id,
        include_subcategories: true,
      };

      const events = await this.discoursePostEventApi.events(params);
      return this.formattedEvents(events);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  get tagsColorsMap() {
    return JSON.parse(this.siteSettings.map_events_to_color);
  }

  get shouldRender() {
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

    return settings.findBy("categoryId", this.category.id.toString());
  }

  @action
  formattedEvents(events = []) {
    return events.map((event) => {
      const { startsAt, endsAt, post, categoryId } = event;

      let backgroundColor;

      if (post.topic.tags) {
        const tagColorEntry = this.tagsColorsMap.find(
          (entry) =>
            entry.type === "tag" && post.topic.tags.includes(entry.slug)
        );
        backgroundColor = tagColorEntry ? tagColorEntry.color : null;
      }

      if (!backgroundColor) {
        const categoryColorFromMap = this.tagsColorsMap.find(
          (entry) =>
            entry.type === "category" && entry.slug === post.topic.category_slug
        )?.color;
        backgroundColor =
          categoryColorFromMap || `#${Category.findById(categoryId)?.color}`;
      }

      let classNames;
      if (moment(endsAt || startsAt).isBefore(moment())) {
        classNames = "fc-past-event";
      }

      return {
        title: formatEventName(event, this.currentUser?.user_option?.timezone),
        start: startsAt,
        display: "list-item",
        rrule: event.rrule,
        end: endsAt || startsAt,
        duration: event.duration,
        allDay: !isNotFullDayEvent(moment(startsAt), moment(endsAt)),
        url: getURL(`/t/-/${post.topic.id}/${post.post_number}`),
        backgroundColor,
        classNames,
      };
    });
  }

  <template>
    {{#if this.shouldRender}}
      <FullCalendar
        @onLoadEvents={{this.loadEvents}}
        @height="650px"
        @initialView={{this.categorySetting?.defaultView}}
        @weekends={{this.renderWeekends}}
      />
    {{/if}}
  </template>
}
