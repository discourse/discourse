import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { or } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import { isNotFullDayEvent } from "../lib/guess-best-date-format";

export const DEFAULT_TIME_FORMAT = "LT";
const DEFAULT_UPCOMING_DAYS = 180;
const DEFAULT_COUNT = 8;

function addToResult(date, item, result) {
  const day = date.format("DD");
  const monthKey = date.format("YYYY-MM");

  result[monthKey] = result[monthKey] ?? {};
  result[monthKey][day] = result[monthKey][day] ?? [];
  result[monthKey][day].push(item);
}

export default class UpcomingEventsList extends Component {
  @service appEvents;
  @service siteSettings;
  @service router;

  @tracked isLoading = true;
  @tracked hasError = false;
  @tracked eventsByMonth = {};

  timeFormat = this.args.params?.timeFormat ?? DEFAULT_TIME_FORMAT;
  count = this.args.params?.count ?? DEFAULT_COUNT;
  upcomingDays = this.args.params?.upcomingDays ?? DEFAULT_UPCOMING_DAYS;

  emptyMessage = i18n("discourse_post_event.upcoming_events_list.empty");
  allDayLabel = i18n("discourse_post_event.upcoming_events_list.all_day");
  errorMessage = i18n("discourse_post_event.upcoming_events_list.error");
  viewAllLabel = i18n("discourse_post_event.upcoming_events_list.view_all");

  constructor() {
    super(...arguments);
    this.appEvents.on("page:changed", this, this.updateEventsList);
  }

  get categoryId() {
    return this.router.currentRoute.attributes?.category?.id;
  }

  get hasEmptyResponse() {
    return (
      !this.isLoading &&
      !this.hasError &&
      Object.keys(this.eventsByMonth).length === 0
    );
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
    };

    if (this.categoryId) {
      data.category_id = this.categoryId;
    }

    try {
      const { events } = await ajax("/discourse-post-event/events", {
        data,
      });

      this.eventsByMonth = this.groupByMonthAndDay(events);
    } catch {
      this.hasError = true;
    } finally {
      this.isLoading = false;
    }
  }

  @action
  formatTime({ starts_at, ends_at }) {
    return isNotFullDayEvent(moment(starts_at), moment(ends_at))
      ? moment(starts_at).format(this.timeFormat)
      : this.allDayLabel;
  }

  @action
  startsAtMonth(month, day) {
    return moment(`${month}-${day}`).format("MMM");
  }

  @action
  startsAtDay(month, day) {
    return moment(`${month}-${day}`).format("D");
  }

  groupByMonthAndDay(data) {
    return data.reduce((result, item) => {
      const startDate = moment(item.starts_at);
      const endDate = item.ends_at ? moment(item.ends_at) : null;
      const today = moment();

      if (!endDate) {
        addToResult(startDate, item, result);
        return result;
      }

      while (startDate.isSameOrBefore(endDate, "day")) {
        if (startDate.isAfter(today)) {
          addToResult(startDate, item, result);
        }

        startDate.add(1, "day");
      }

      return result;
    }, {});
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
            {{#each-in this.eventsByMonth as |month monthData|}}
              {{#each-in monthData as |day events|}}
                {{#each events as |event|}}
                  <a
                    class="upcoming-events-list__event"
                    href={{event.post.url}}
                  >
                    <div class="upcoming-events-list__event-date">
                      <div class="month">{{this.startsAtMonth month day}}</div>
                      <div class="day">{{this.startsAtDay month day}}</div>
                    </div>
                    <div class="upcoming-events-list__event-content">
                      <span
                        class="upcoming-events-list__event-name"
                        title={{or event.name event.post.topic.title}}
                      >
                        {{or event.name event.post.topic.title}}
                      </span>
                      {{#if this.timeFormat}}
                        <span class="upcoming-events-list__event-time">
                          {{this.formatTime event}}
                        </span>
                      {{/if}}
                    </div>
                  </a>
                {{/each}}
              {{/each-in}}
            {{/each-in}}
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
