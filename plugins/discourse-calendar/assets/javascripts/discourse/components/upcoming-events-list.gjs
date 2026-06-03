import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import { i18n } from "discourse-i18n";
import {
  fetchUpcomingEvents,
  upcomingEventsListTitle,
} from "../lib/upcoming-events";
import UpcomingEventsListView from "./upcoming-events-list-view";

export const DEFAULT_TIME_FORMAT = "LT";
const DEFAULT_UPCOMING_DAYS = 180;
const DEFAULT_COUNT = 8;

/**
 * Self-fetching upcoming-events widget for standalone use (e.g. the
 * `discourse-right-sidebar-blocks` theme). It owns the loading / empty /
 * error+retry states and refreshes on `page:changed`, then delegates the
 * actual list rendering to the pure `UpcomingEventsListView`. The fetch and
 * grouping live in the shared `lib/upcoming-events` module, which the block
 * variant resolves through the blocks data layer instead.
 */
export default class UpcomingEventsList extends Component {
  @service appEvents;
  @service siteSettings;
  @service router;

  @tracked isLoading = true;
  @tracked hasError = false;
  @tracked eventsByMonth = new Map();

  timeFormat = this.args.params?.timeFormat ?? DEFAULT_TIME_FORMAT;
  count = this.args.params?.count ?? DEFAULT_COUNT;
  upcomingDays = this.args.params?.upcomingDays ?? DEFAULT_UPCOMING_DAYS;
  includeSubcategories = this.args.params?.includeSubcategories ?? false;

  emptyMessage = i18n("discourse_post_event.upcoming_events_list.empty");
  errorMessage = i18n("discourse_post_event.upcoming_events_list.error");
  viewAllLabel = i18n("discourse_post_event.upcoming_events_list.view_all");

  constructor() {
    super(...arguments);
    this.appEvents.on("page:changed", this, this.updateEventsList);
    // `page:changed` is the only refresh trigger, so consumers mounted outside
    // a route transition (e.g. block-based renders on a frozen homepage) need
    // an explicit initial fetch.
    this.updateEventsList();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("page:changed", this, this.updateEventsList);
  }

  /**
   * The category to scope the list to: the explicitly-passed param, otherwise
   * the current route's category.
   *
   * @returns {number|undefined}
   */
  get categoryId() {
    return (
      this.args.params?.categoryId ??
      this.router.currentRoute.attributes?.category?.id
    );
  }

  /**
   * Whether the list resolved with no events to show.
   *
   * @returns {boolean}
   */
  get hasEmptyResponse() {
    return !this.isLoading && !this.hasError && this.eventsByMonth.size === 0;
  }

  /**
   * The heading text, honouring the `map_events_title` per-category setting.
   *
   * @returns {string}
   */
  get title() {
    return upcomingEventsListTitle({
      router: this.router,
      siteSettings: this.siteSettings,
    });
  }

  /**
   * Fetches and groups the upcoming events, toggling the loading / error flags.
   * Bound to `page:changed` and run once on insert.
   */
  @action
  async updateEventsList() {
    this.isLoading = true;
    this.hasError = false;

    try {
      this.eventsByMonth =
        (await fetchUpcomingEvents({
          count: this.count,
          upcomingDays: this.upcomingDays,
          categoryId: this.categoryId,
          includeSubcategories: this.includeSubcategories,
        })) ?? new Map();
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
        <DConditionalLoadingSpinner @condition={{this.isLoading}} />

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
          <UpcomingEventsListView
            @eventsByMonth={{this.eventsByMonth}}
            @timeFormat={{this.timeFormat}}
          />
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
