import Component from "@glimmer/component";
import { action } from "@ember/object";
import PluginOutlet from "discourse/components/plugin-outlet";
import { or } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { isNotFullDayEvent } from "../lib/guess-best-date-format";
import { isMultiDayEvent } from "../lib/upcoming-events";

/**
 * Pure renderer for an upcoming-events list. Given the events already grouped
 * by month and day (see `groupUpcomingEventsByMonthAndDay`), it renders the
 * date-stamped event links. It does no fetching and owns no loading/error
 * state — the self-fetching `UpcomingEventsList` wrapper and the block both
 * supply the resolved `@eventsByMonth`.
 */
export default class UpcomingEventsListView extends Component {
  allDayLabel = i18n("discourse_post_event.upcoming_events_list.all_day");

  /**
   * Formats an event's time cell: a date range for multi-day events, the start
   * time for timed events, or the all-day label otherwise.
   *
   * @param {object} event - The event record.
   * @returns {string} The formatted time string.
   */
  @action
  formatTime(event) {
    if (isMultiDayEvent(event)) {
      return this.#formatDateRange(event);
    }

    const startsAt = moment(event.starts_at);
    const endsAt = event.ends_at ? moment(event.ends_at) : null;

    return isNotFullDayEvent(startsAt, endsAt)
      ? startsAt.format(this.args.timeFormat)
      : this.allDayLabel;
  }

  /**
   * The abbreviated month label for a grouped month/day key.
   *
   * @param {string} month - The `YYYY-MM` month key.
   * @param {string} day - The `DD` day key.
   * @returns {string} The localized short month (e.g. "Jun").
   */
  @action
  startsAtMonth(month, day) {
    return moment(`${month}-${day}`).format("MMM");
  }

  /**
   * The day-of-month number for a grouped month/day key.
   *
   * @param {string} month - The `YYYY-MM` month key.
   * @param {string} day - The `DD` day key.
   * @returns {string} The day number (e.g. "5").
   */
  @action
  startsAtDay(month, day) {
    return moment(`${month}-${day}`).format("D");
  }

  /**
   * Formats a multi-day event as a locale-aware date range.
   *
   * @param {object} event - The event record.
   * @returns {string} The formatted range (e.g. "June 5 – 10, 2025").
   */
  #formatDateRange(event) {
    // Date-only strings (all-day events) must be parsed as local dates;
    // `new Date("YYYY-MM-DD")` treats them as UTC, shifting the day in western
    // timezones.
    const start = event.all_day
      ? new Date(event.starts_at + "T00:00:00")
      : new Date(event.starts_at);
    const end = event.all_day
      ? new Date(event.ends_at + "T00:00:00")
      : new Date(event.ends_at);

    return new Intl.DateTimeFormat(moment.locale(), {
      month: "long",
      day: "numeric",
      year: "numeric",
    }).formatRange(start, end);
  }

  <template>
    <PluginOutlet @name="upcoming-events-list-container">
      {{#each-in @eventsByMonth as |month monthData|}}
        {{#each-in monthData as |day events|}}
          {{#each events as |event|}}
            <a class="upcoming-events-list__event" href={{event.post.url}}>
              <div class="upcoming-events-list__event-date">
                <div class="month">{{this.startsAtMonth month day}}</div>
                <div class="day">{{this.startsAtDay month day}}</div>
              </div>
              <div class="upcoming-events-list__event-content">
                <span
                  class="upcoming-events-list__event-name"
                  title={{or event.name event.post.topic.title}}
                >
                  {{#if event.recurrence}}
                    {{dIcon "arrows-rotate"}}
                  {{/if}}
                  {{or event.name event.post.topic.title}}
                </span>
                {{#if @timeFormat}}
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
  </template>
}
