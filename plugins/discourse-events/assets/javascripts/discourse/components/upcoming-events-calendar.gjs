import Component from "@glimmer/component";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import moment from "moment";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import { normalizeViewForRoute } from "../lib/calendar-view-helper";
import formatEventForCalendar from "../lib/format-event-for-calendar";
import openEventComposer from "../lib/open-event-composer";
import FullCalendar from "./full-calendar";

export default class UpcomingEventsCalendar extends Component {
  @service composer;
  @service currentUser;
  @service router;
  @service capabilities;
  @service siteSettings;
  @service discoursePostEventService;

  get canCreateEvent() {
    if (!this.currentUser) {
      return false;
    }

    return (
      this.currentUser.can_create_discourse_post_event &&
      this.currentUser.can_create_topic
    );
  }

  @action
  async onDateClick(info) {
    await openEventComposer({
      composer: this.composer,
      currentUser: this.currentUser,
      siteSettings: this.siteSettings,
      info,
      category: this.args.categoryId
        ? (Category.findById(this.args.categoryId) ?? null)
        : null,
    });
  }

  get customButtons() {
    return {
      mineEvents: {
        text: i18n("discourse_post_event.upcoming_events.my_events"),
        click: () => {
          const params = this.router.currentRoute.params;
          this.router.replaceWith(
            "discourse-post-event-upcoming-events.mine",
            params.view,
            params.year,
            params.month,
            params.day
          );
        },
      },
      allEvents: {
        text: i18n("discourse_post_event.upcoming_events.all_events"),
        click: () => {
          const params = this.router.currentRoute.params;
          this.router.replaceWith(
            "discourse-post-event-upcoming-events.index",
            params.view,
            params.year,
            params.month,
            params.day
          );
        },
      },
    };
  }

  @action
  async loadEvents(info) {
    const params = {
      after: info.startStr,
      before: info.endStr,
      include_ongoing: true,
      attending_user: this.args.mine ? this.currentUser?.username : null,
    };

    if (this.args.categoryId) {
      params.category_id = this.args.categoryId;
    }

    if (this.args.includeSubcategories !== undefined) {
      params.include_subcategories = this.args.includeSubcategories;
    }

    const events = await this.discoursePostEventService.fetchEvents(params);

    const timezone = this.currentUser?.user_option?.timezone;

    return events.map((event) =>
      formatEventForCalendar(
        event,
        this.siteSettings.map_events_to_color,
        timezone
      )
    );
  }

  get refreshKey() {
    return [
      this.currentUser?.id,
      this.args.categoryId,
      this.args.includeSubcategories,
    ].join("-");
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

    if (this.args.updateRouteOnDatesChange === false) {
      return;
    }

    const localDate = moment(info.view.currentStart)
      .clone()
      .tz(this.currentUser?.user_option?.timezone ?? moment.tz.guess());

    this.router.replaceWith(
      this.router.currentRouteName,
      normalizeViewForRoute(info.view.type),
      localDate.year(),
      localDate.month() + 1,
      localDate.date()
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
        @onDateClick={{if this.canCreateEvent this.onDateClick}}
        @onLoadEvents={{this.loadEvents}}
        @initialView={{@initialView}}
        @customButtons={{this.customButtons}}
        @leftHeaderToolbar={{this.leftHeaderToolbar}}
        @centerHeaderToolbar={{this.centerHeaderToolbar}}
        @rightHeaderToolbar={{this.rightHeaderToolbar}}
        @refreshKey={{this.refreshKey}}
      />
    </div>
  </template>
}
