import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import moment from "moment";
import getURL from "discourse/lib/get-url";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import { formatEventName } from "../helpers/format-event-name";
import { isNotFullDayEvent } from "../lib/guess-best-date-format";
import FullCalendar from "./full-calendar";

export default class UpcomingEventsCalendar extends Component {
  @service currentUser;
  @service site;
  @service router;
  @service capabilities;
  @service siteSettings;
  @service discoursePostEventService;

  @tracked resolvedEvents;

  _calendar = null;

  get customButtons() {
    if (
      this.router.currentRouteName ===
      "discourse-post-event-upcoming-events.index"
    ) {
      return {
        mineEvents: {
          text: i18n("discourse_post_event.upcoming_events.my_events"),
          click: () => {
            this.router.transitionTo(
              "discourse-post-event-upcoming-events.mine"
            );
          },
        },
      };
    } else if (
      this.router.currentRouteName ===
      "discourse-post-event-upcoming-events.mine"
    ) {
      return {
        allEvents: {
          text: i18n("discourse_post_event.upcoming_events.all_events"),
          click: () => {
            this.router.transitionTo(
              "discourse-post-event-upcoming-events.index"
            );
          },
        },
      };
    }
  }

  get events() {
    if (!this.resolvedEvents) {
      return [];
    }

    const tagsColorsMap = JSON.parse(this.siteSettings.map_events_to_color);

    return (this.resolvedEvents || []).map((event) => {
      const { startsAt, endsAt, post, categoryId } = event;

      let backgroundColor;

      if (post.topic.tags) {
        const tagColorEntry = tagsColorsMap.find(
          (entry) =>
            entry.type === "tag" && post.topic.tags.includes(entry.slug)
        );
        backgroundColor = tagColorEntry?.color;
      }

      if (!backgroundColor) {
        const categoryColorEntry = tagsColorsMap.find(
          (entry) =>
            entry.type === "category" && entry.slug === post.topic.category_slug
        );
        backgroundColor = categoryColorEntry?.color;
      }

      const categoryColor = Category.findById(categoryId)?.color;
      if (!backgroundColor && categoryColor) {
        backgroundColor = `#${categoryColor}`;
      }

      let classNames;
      if (moment(endsAt || startsAt).isBefore(moment())) {
        classNames = "fc-past-event";
      }

      return {
        extendedProps: { postEvent: event },
        title: formatEventName(event, this.currentUser?.user_option?.timezone),
        rrule: event.rrule,
        start: startsAt,
        end: endsAt || startsAt,
        allDay: !isNotFullDayEvent(moment(startsAt), moment(endsAt)),
        url: getURL(`/t/-/${post.topic.id}/${post.post_number}`),
        backgroundColor,
        classNames,
      };
    });
  }

  get leftHeaderToolbar() {
    let left = "";

    if (!this.capabilities.viewport.sm) {
      left = `title ${this.customButtonName}`;
    } else {
      left += this.customButtonName;
    }

    if (!this.capabilities.viewport.sm) {
      return left;
    } else {
      return `${left} prev,next,today`;
    }
  }

  get customButtonName() {
    if (
      this.router.currentRouteName ===
      "discourse-post-event-upcoming-events.index"
    ) {
      return "mineEvents";
    } else if (
      this.router.currentRouteName ===
      "discourse-post-event-upcoming-events.mine"
    ) {
      return "allEvents";
    }
  }

  get rightHeaderToolbar() {
    if (!this.capabilities.viewport.sm) {
      return "prev,next timeGridDay,timeGridWeek,dayGridMonth,listYear";
    } else {
      return "timeGridDay,timeGridWeek,dayGridMonth,listYear";
    }
  }

  get centerHeaderToolbar() {
    if (!this.capabilities.viewport.sm) {
      return "";
    } else {
      return "title";
    }
  }

  @action
  async fetchEvents(info) {
    this.resolvedEvents = null;

    const params = {};
    params.after = info.startStr;
    params.before = info.endStr;

    if (this.args.mine) {
      params.attending_user = this.currentUser?.username;
    }

    this.resolvedEvents =
      await this.discoursePostEventService.fetchEvents(params);
  }

  <template>
    <div id="upcoming-events-calendar">
      <FullCalendar
        @onDatesChange={{this.fetchEvents}}
        @events={{this.events}}
        @initialView={{@controller.view}}
        @customButtons={{this.customButtons}}
        @leftHeaderToolbar={{this.leftHeaderToolbar}}
        @centerHeaderToolbar={{this.centerHeaderToolbar}}
        @rightHeaderToolbar={{this.rightHeaderToolbar}}
      />
    </div>
  </template>
}
