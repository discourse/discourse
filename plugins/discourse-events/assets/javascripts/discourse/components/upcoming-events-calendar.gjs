import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import moment from "moment";
import MobileTabBarViews from "discourse/components/mobile-tab-bar/views";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import { normalizeViewForRoute } from "../lib/calendar-view-helper.js";
import formatEventForCalendar from "../lib/format-event-for-calendar.js";
import openEventComposer from "../lib/open-event-composer.js";
import {
  checkPersonalEvents,
  knownPersonalEvents,
} from "../lib/personal-events-check.js";
import {
  canCreateRegistrationForm,
  registrationFormManagementUrl,
} from "../lib/registration-forms.js";
import { UPCOMING_EVENTS_TAB_KEY } from "../lib/upcoming-events-tab.js";
import FullCalendar from "./full-calendar.gjs";

const eventViews = [
  {
    button: "allEvents",
    label: "discourse_post_event.upcoming_events.all_events",
    route: "discourse-post-event-upcoming-events.index",
  },
  {
    button: "mineEvents",
    label: "discourse_post_event.upcoming_events.my_events",
    route: "discourse-post-event-upcoming-events.mine",
  },
];

export default class UpcomingEventsCalendar extends Component {
  @service composer;
  @service currentUser;
  @service mobileTabBar;
  @service router;
  @service capabilities;
  @service siteSettings;
  @service discoursePostEventApi;

  @tracked hasPersonalEvents = knownPersonalEvents(this.currentUser);

  constructor() {
    super(...arguments);
    this.#checkPersonalEvents();
  }

  get canCreateEvent() {
    if (!this.currentUser) {
      return false;
    }

    return (
      this.currentUser.can_create_discourse_post_event &&
      this.currentUser.can_create_topic
    );
  }

  get composerCategory() {
    if (this.args.categoryId) {
      return Category.findById(this.args.categoryId) ?? null;
    }

    const category = Category.findById(
      this.siteSettings.calendar_upcoming_events_default_category
    );
    return category?.canCreateTopic ? category : null;
  }

  get customButtons() {
    const buttons = {};
    for (const { button, label, route } of eventViews) {
      buttons[button] = {
        text: i18n(label),
        click: () =>
          this.router.replaceWith(route, ...this.calendarRouteModels),
      };
    }
    return buttons;
  }

  get calendarRouteModels() {
    const { view, year, month, day } = this.router.currentRoute.params;
    return [view, year, month, day];
  }

  get viewsInFooter() {
    return (
      this.mobileTabBar.enabled &&
      this.mobileTabBar.sectionTabKey === UPCOMING_EVENTS_TAB_KEY
    );
  }

  // My events stays reachable while it's open, even on days it has nothing
  get showFooterViews() {
    return (
      this.viewsInFooter &&
      !!this.currentUser &&
      (this.args.mine || this.hasPersonalEvents)
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
    if (this.viewsInFooter) {
      return this.capabilities.viewport.sm ? "prev,next,today" : "title";
    }

    return this.capabilities.viewport.sm
      ? "allEvents,mineEvents prev,next,today"
      : "title allEvents,mineEvents";
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
  async onDateClick(info) {
    await openEventComposer({
      composer: this.composer,
      currentUser: this.currentUser,
      siteSettings: this.siteSettings,
      info,
      category: this.composerCategory,
    });
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

    const events = await this.discoursePostEventApi.events(params);

    const timezone = this.currentUser?.user_option?.timezone;

    return events.map((event) =>
      formatEventForCalendar(
        event,
        this.siteSettings.map_events_to_color,
        timezone
      )
    );
  }

  @action
  async onDatesChange(info) {
    if (!this.viewsInFooter) {
      this.applyCustomButtonsState(info.view.calendar.el);
    }

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
  applyCustomButtonsState(element) {
    schedule("afterRender", () => {
      element
        .querySelector(".fc-mineEvents-button")
        ?.classList.toggle("fc-button-active", !!this.args.mine);
      element
        .querySelector(".fc-allEvents-button")
        ?.classList.toggle("fc-button-active", !this.args.mine);
    });
  }

  async #checkPersonalEvents() {
    const user = this.currentUser;

    if (!user || !this.mobileTabBar.enabled) {
      return;
    }

    const hasEvents = await checkPersonalEvents(
      this.discoursePostEventApi,
      user
    );
    if (!this.isDestroying) {
      this.hasPersonalEvents = hasEvents;
    }
  }

  <template>
    {{#if this.showFooterViews}}
      <MobileTabBarViews>
        <ul class="nav nav-pills">
          {{#each eventViews as |view|}}
            <li>
              <LinkTo
                aria-current={{if
                  (eq this.router.currentRouteName view.route)
                  "page"
                }}
                @models={{this.calendarRouteModels}}
                @replace={{true}}
                @route={{view.route}}
              >{{i18n view.label}}</LinkTo>
            </li>
          {{/each}}
        </ul>
      </MobileTabBarViews>
    {{/if}}
    <div id="upcoming-events-calendar">
      {{#if
        (and
          @mine (canCreateRegistrationForm this.currentUser this.siteSettings)
        )
      }}
        <a href={{registrationFormManagementUrl this.currentUser}}>{{i18n
            "event_registration.library.manage"
          }}</a>
      {{/if}}
      <FullCalendar
        @centerHeaderToolbar={{this.centerHeaderToolbar}}
        @customButtons={{this.customButtons}}
        @initialDate={{@initialDate}}
        @initialView={{@initialView}}
        @leftHeaderToolbar={{this.leftHeaderToolbar}}
        @onDateClick={{if this.canCreateEvent this.onDateClick}}
        @onDatesChange={{this.onDatesChange}}
        @onLoadEvents={{this.loadEvents}}
        @refreshKey={{this.refreshKey}}
        @rightHeaderToolbar={{this.rightHeaderToolbar}}
      />
    </div>
  </template>
}
