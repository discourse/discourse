import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import moment from "moment";
import getURL from "discourse/lib/get-url";
import loadFullCalendar from "discourse/lib/load-full-calendar";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import { formatEventName } from "../helpers/format-event-name";
import addRecurrentEvents from "../lib/add-recurrent-events";
import fullCalendarDefaultOptions from "../lib/full-calendar-default-options";
import { isNotFullDayEvent } from "../lib/guess-best-date-format";
import FullCalendar from "./full-calendar";

export default class UpcomingEventsCalendar extends Component {
  @service currentUser;
  @service site;
  @service router;
  @service capabilities;
  @service siteSettings;

  @tracked resolvedEvents;

  _calendar = null;

  constructor() {
    super(...arguments);

    this.resolvedEvents = this.args.events
      ? this.args.events
      : this.args.controller.model;
  }

  get displayFilters() {
    return this.currentUser && this.args.controller;
  }

  @action
  teardown() {
    this._calendar?.destroy?.();
    this._calendar = null;
  }

  @action
  async renderCalendar(calendarNode) {
    const calendarModule = await loadFullCalendar();

    let headerToolbar;

    if (!this.capabilities.viewport.sm) {
      headerToolbar = {
        left: "title prev,next,today",
        center: "allEvents,mineEvents timeGridWeek,timeGridDay,listNextYear",
        right: "",
      };
    } else {
      headerToolbar = {
        left: "allEvents,mineEvents prev,next,today",
        center: "title",
        right: "timeGridWeek,timeGridDay,listNextYear",
      };
    }

    this._calendar = new calendarModule.Calendar(calendarNode, {
      ...fullCalendarDefaultOptions(),

      datesSet: (info) => {
        if (this.router?.transitionTo) {
          this.router.transitionTo({ queryParams: { view: info.view.type } });
        }
      },
      headerToolbar,
    });

    this._calendar.render();
  }

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
    const tagsColorsMap = JSON.parse(this.siteSettings.map_events_to_color);
    const originalEventAndRecurrents = addRecurrentEvents(this.resolvedEvents);

    return (originalEventAndRecurrents || []).map((event) => {
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

  <template>
    <div id="upcoming-events-calendar">
      <FullCalendar
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
