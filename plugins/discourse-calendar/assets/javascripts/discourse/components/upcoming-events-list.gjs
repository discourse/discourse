import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import FullCalendar from "./full-calendar";

export const DEFAULT_TIME_FORMAT = "LT";
const DEFAULT_UPCOMING_DAYS = 180;
const DEFAULT_COUNT = 8;

export default class UpcomingEventsList extends Component {
  @service appEvents;
  @service siteSettings;
  @service router;

  @tracked isLoading = true;
  @tracked hasError = false;
  @tracked eventsByMonth = new Map();
  @tracked events;

  initialdate = moment().toISOString();
  timeFormat = this.args.params?.timeFormat ?? DEFAULT_TIME_FORMAT;
  count = this.args.params?.count ?? DEFAULT_COUNT;
  upcomingDays = this.args.params?.upcomingDays ?? DEFAULT_UPCOMING_DAYS;

  emptyMessage = i18n("discourse_post_event.upcoming_events_list.empty");
  errorMessage = i18n("discourse_post_event.upcoming_events_list.error");
  viewAllLabel = i18n("discourse_post_event.upcoming_events_list.view_all");

  constructor() {
    super(...arguments);
    this.appEvents.on("page:changed", this, this.updateEventsList);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("page:changed", this, this.updateEventsList);
  }

  get categoryId() {
    return this.router.currentRoute.attributes?.category?.id;
  }

  get hasEmptyResponse() {
    return !this.isLoading && !this.hasError && !this.events?.length;
  }

  get title() {
    const categorySlug = this.router.currentRoute.attributes?.category?.slug;
    const titleSetting = this.siteSettings.map_events_title;

    if (titleSetting === "") {
      return i18n("discourse_post_event.upcoming_events_list.title");
    }

    const categories = JSON.parse(titleSetting).map(
      ({ category_slug }) => category_slug
    );

    if (categories.includes(categorySlug)) {
      const titleMap = JSON.parse(titleSetting);
      const customTitleLookup = titleMap.find(
        (o) => o.category_slug === categorySlug
      );
      return customTitleLookup?.custom_title;
    } else {
      return i18n("discourse_post_event.upcoming_events_list.title");
    }
  }

  @action
  async updateEventsList() {
    this.isLoading = true;
    this.hasError = false;

    const data = {
      limit: this.count,
      before: moment().add(this.upcomingDays, "days").toISOString(),
      after: moment().toISOString(),
    };

    if (this.categoryId) {
      data.category_id = this.categoryId;
    }

    try {
      const { events } = await ajax("/discourse-post-event/events", {
        data,
      });

      this.events = events.map((event) => {
        return {
          title: event.name || event.post.topic.title,
          rrule: event.rrule,
          duration: event.duration,
          start: moment(event.starts_at).toISOString(),
          end: moment(event.ends_at).toISOString(),
          extendedProps: { postEvent: event },
        };
      });
    } catch {
      this.hasError = true;
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    <div class="upcoming-events-list">
      <h3 class="upcoming-events-list__heading">
        {{this.title}}
      </h3>

      <div class="upcoming-events-list__container">
        <ConditionalLoadingSpinner @condition={{this.isLoading}} />

        {{#if this.hasEmptyResponse}}
          <div class="upcoming-events-list__empty-message">
            {{this.emptyMessage}}
          </div>
        {{/if}}

        {{#if this.hasError}}
          <div class="upcoming-events-list__error-message">
            {{this.errorMessage}}
          </div>
          <DButton
            @action={{this.updateEventsList}}
            @label="discourse_post_event.upcoming_events_list.try_again"
            class="btn-link upcoming-events-list__try-again"
          />
        {{/if}}

        {{#unless this.isLoading}}
          <PluginOutlet @name="upcoming-events-list-container">
            <FullCalendar
              @height="500px"
              @initialDate={{this.initialDate}}
              @events={{this.events}}
              @initialView="year"
              @leftHeaderToolbar=""
              @centerHeaderToolbar=""
              @rightHeaderToolbar=""
              @displayEventTime={{false}}
            />
          </PluginOutlet>
        {{/unless}}
      </div>

      <div class="upcoming-events-list__footer">
        <LinkTo
          @route="discourse-post-event-upcoming-events"
          class="upcoming-events-list__view-all"
        >
          {{this.viewAllLabel}}
        </LinkTo>
      </div>
    </div>
  </template>
}
