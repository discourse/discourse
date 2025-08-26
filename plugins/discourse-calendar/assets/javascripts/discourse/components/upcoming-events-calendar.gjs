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

  _isInitializing = true;
  _isViewChanging = false;

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

    const view = normalizeViewForRoute(info.view.type);
    const currentParams = this.router.currentRoute.params;
    const currentYear = parseInt(currentParams.year, 10);
    const currentMonth = parseInt(currentParams.month, 10);
    const currentDay = parseInt(currentParams.day, 10);

    const isViewChanged = currentParams.view !== view;

    // For view changes, always preserve the current URL parameters
    if (isViewChanged) {
      this._isViewChanging = true;
      this.router.replaceWith(
        this.router.currentRouteName,
        view,
        currentYear,
        currentMonth,
        currentDay
      );
      return;
    }

    // Skip navigation logic immediately after a view change
    if (this._isViewChanging) {
      this._isViewChanging = false;
      return;
    }

    const {
      year: urlYear,
      month: urlMonth,
      day: urlDay,
    } = this.#calculateUrlParams(
      view,
      info.view,
      currentYear,
      currentMonth,
      currentDay,
      isViewChanged
    );

    const isMonthChanged =
      view === "month" &&
      (currentYear !== urlYear || currentMonth !== urlMonth);
    const isDayChanged =
      view !== "month" &&
      (currentYear !== urlYear ||
        currentMonth !== urlMonth ||
        currentDay !== urlDay);

    // Prevent URL changes during calendar initialization
    if (this._isInitializing) {
      this._isInitializing = false;
      return;
    }

    if (isViewChanged || isMonthChanged || isDayChanged) {
      this.router.replaceWith(
        this.router.currentRouteName,
        view,
        urlYear,
        urlMonth,
        urlDay
      );
    }
  }

  #calculateUrlParams(
    view,
    calendarView,
    currentYear,
    currentMonth,
    currentDay,
    isViewChanged = false
  ) {
    const viewStart = moment(calendarView.currentStart);
    const viewEnd = moment(calendarView.currentEnd);
    const currentParams = this.router.currentRoute.params;

    // For view changes, preserve the current date from URL
    if (isViewChanged) {
      return {
        year: currentYear,
        month: currentMonth,
        day: parseInt(currentParams.day, 10),
      };
    }

    if (view === "month") {
      const startYear = viewStart.year();
      const startMonth = viewStart.month() + 1;

      if (
        this.#isSequentialMonthNavigation(
          currentYear,
          currentMonth,
          startYear,
          startMonth
        )
      ) {
        return { year: startYear, month: startMonth, day: 1 };
      } else if (
        this.#isTodayNavigation(currentParams, startYear, startMonth)
      ) {
        return { year: startYear, month: startMonth, day: moment().date() };
      } else {
        const viewMiddle = moment(
          (viewStart.valueOf() + viewEnd.valueOf()) / 2
        );
        return {
          year: viewMiddle.year(),
          month: viewMiddle.month() + 1,
          day: viewMiddle.date(),
        };
      }
    } else {
      // For view changes, preserve the current date from URL
      if (isViewChanged) {
        return {
          year: currentYear,
          month: currentMonth,
          day: currentDay,
        };
      }

      // For navigation (next/prev/today), calculate based on the calendar view's current date
      const viewDate = moment(calendarView.currentStart);

      return {
        year: viewDate.year(),
        month: viewDate.month() + 1,
        day: viewDate.date(),
      };
    }
  }

  #isSequentialMonthNavigation(currentYear, currentMonth, newYear, newMonth) {
    if (newYear === currentYear && newMonth === currentMonth + 1) {
      return true;
    }
    if (newYear === currentYear && newMonth === currentMonth - 1) {
      return true;
    }
    if (newYear === currentYear + 1 && newMonth === 1 && currentMonth === 12) {
      return true;
    }
    if (newYear === currentYear - 1 && newMonth === 12 && currentMonth === 1) {
      return true;
    }

    return false;
  }

  #isTodayNavigation(currentParams, newYear, newMonth) {
    const today = moment();
    return (
      newYear === today.year() &&
      newMonth === today.month() + 1 &&
      (currentParams.year !== newYear || currentParams.month !== newMonth)
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
