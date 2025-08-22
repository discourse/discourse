import Component from "@glimmer/component";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import moment from "moment";
import getURL from "discourse/lib/get-url";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import { formatEventName } from "../helpers/format-event-name";
import { normalizeViewForRoute } from "../lib/calendar-view-helper";
import { isNotFullDayEvent } from "../lib/guess-best-date-format";
import FullCalendar from "./full-calendar";

export default class UpcomingEventsCalendar extends Component {
  @service currentUser;
  @service router;
  @service capabilities;
  @service siteSettings;

  get customButtons() {
    return {
      mineEvents: {
        text: i18n("discourse_post_event.upcoming_events.my_events"),
        click: () => {
          const params = this.router.currentRoute.params;
          this.router.replaceWith(
            "discourse-post-event-upcoming-events.mine",
            params.view || "month",
            params.year || moment().year(),
            params.month || moment().month() + 1,
            params.day || moment().date()
          );
        },
      },
      allEvents: {
        text: i18n("discourse_post_event.upcoming_events.all_events"),
        click: () => {
          const params = this.router.currentRoute.params;
          this.router.replaceWith(
            "discourse-post-event-upcoming-events.index",
            params.view || "month",
            params.year || moment().year(),
            params.month || moment().month() + 1,
            params.day || moment().date()
          );
        },
      },
    };
  }

  get events() {
    if (!this.args.events) {
      return [];
    }

    const tagsColorsMap = JSON.parse(this.siteSettings.map_events_to_color);

    return this.args.events.map((event) => {
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
      left = `title allEvents,mineEvents`;
    } else {
      left += "allEvents,mineEvents";
    }

    if (!this.capabilities.viewport.sm) {
      return left;
    } else {
      return `${left} prev,next,today`;
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
  async onDatesChange(info) {
    this.applyCustomButtonsState();

    // Skip navigation if this is the initial calendar setup
    // FullCalendar triggers datesSet immediately after initialization
    if (!this._calendarInitialized) {
      this._calendarInitialized = true;
      return;
    }

    // Get a representative date from the current view
    const currentDate = moment(info.view.currentStart);
    const view = normalizeViewForRoute(info.view.type);
    const year = currentDate.year();
    const month = currentDate.month() + 1; // moment months are 0-indexed, but URLs use 1-indexed
    const day = currentDate.date();

    // Navigate to the new route structure
    this.router.replaceWith(
      this.router.currentRouteName,
      view,
      year,
      month,
      day
    );
  }

  @action
  applyCustomButtonsState() {
    schedule("afterRender", () => {
      if (this.args.mine) {
        document
          .querySelector(".fc-mineEvents-button")
          .classList.add("fc-button-active");
        document
          .querySelector(".fc-allEvents-button")
          .classList.remove("fc-button-active");
      } else {
        document
          .querySelector(".fc-allEvents-button")
          .classList.add("fc-button-active");
        document
          .querySelector(".fc-mineEvents-button")
          .classList.remove("fc-button-active");
      }
    });
  }

  <template>
    <div id="upcoming-events-calendar">
      <FullCalendar
        @initialDate={{@initialDate}}
        @onDatesChange={{this.onDatesChange}}
        @events={{this.events}}
        @initialView={{@initialView}}
        @customButtons={{this.customButtons}}
        @leftHeaderToolbar={{this.leftHeaderToolbar}}
        @centerHeaderToolbar={{this.centerHeaderToolbar}}
        @rightHeaderToolbar={{this.rightHeaderToolbar}}
      />
    </div>
  </template>
}
