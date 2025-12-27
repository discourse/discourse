import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import UserInfo from "discourse/components/user-info";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import ComboBox from "discourse/select-kit/components/combo-box";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const DAYS = 14;
const MS_PER_DAY = 86400000;
const MEMBER_COL_WIDTH = 180;

const EVENT_EMOJIS = {
  leave: "🏖️",
  sick: "🤒",
  "family-reasons": "👨‍👩‍👧",
  work: "💼",
  "public-holiday": "🎉",
  "authorized-absence": "✅",
  "special-leave": "⭐",
  "parental-leave": "👶",
  default: "📅",
};

/**
 * Strips HTML tags from a string.
 * @param {string} str - The string to strip
 * @returns {string} The stripped string
 */
function stripHtml(str) {
  return (str || "").replace(/<[^>]*>/g, "").trim();
}

/**
 * Strips the event type hashtag from a message.
 * Removes patterns like "#leave ", "#sick(2d) ", etc.
 * @param {string} message - The message to clean
 * @returns {string} The message without the type hashtag
 */
function stripEventTypeHashtag(message) {
  return (message || "").replace(/^#[\w-]+(?:\([^)]*\))?\s*/, "").trim();
}

/**
 * @component TeamAvailabilityCalendar
 *
 * Displays a calendar grid showing team member availability.
 * Shows events (leave, sick, holidays, etc.) as colored bars on a timeline.
 *
 * @param {string} groupName - Optional group name to filter by
 */
export default class TeamAvailabilityCalendar extends Component {
  @service router;

  @tracked loading = true;
  @tracked error = null;
  @tracked startDate = this.#mondayOfWeek(new Date());
  @tracked members = [];
  @tracked eventsByMember = {};
  @tracked groups = [];
  @tracked searchQuery = "";
  @tracked selectedGroup = null;

  constructor() {
    super(...arguments);
    this.#loadData();
  }

  /**
   * @returns {string|null} The currently selected group name
   */
  get selectedGroupName() {
    return this.selectedGroup ?? this.args.groupName ?? null;
  }

  /**
   * @returns {Array<{ id: string, name: string }>} Options for the group dropdown
   */
  get groupOptions() {
    return this.groups.map((g) => ({
      id: g.name,
      name: g.full_name || g.name,
    }));
  }

  /**
   * @returns {Array<Date>} Array of dates for the current view period
   */
  get dates() {
    const dates = [];
    for (let i = 0; i < DAYS; i++) {
      dates.push(new Date(this.startDate.getTime() + i * MS_PER_DAY));
    }
    return dates;
  }

  /**
   * @returns {Array<Object>} Members filtered by search query
   */
  get filteredMembers() {
    let result = this.members;
    if (this.searchQuery) {
      const q = this.searchQuery.toLowerCase();
      result = result.filter(
        (m) =>
          m.username.toLowerCase().includes(q) ||
          m.name?.toLowerCase().includes(q)
      );
    }
    return result;
  }

  /**
   * @returns {string} Formatted date range for display
   */
  get dateRange() {
    const end = new Date(this.startDate.getTime() + (DAYS - 1) * MS_PER_DAY);
    const formatDate = (d) =>
      d.toLocaleDateString(undefined, { month: "short", day: "numeric" });
    return `${formatDate(this.startDate)} - ${formatDate(end)}`;
  }

  /**
   * Checks if a date is today.
   * @param {Date} date - The date to check
   * @returns {boolean}
   */
  isToday(date) {
    const today = new Date();
    return (
      date.getDate() === today.getDate() &&
      date.getMonth() === today.getMonth() &&
      date.getFullYear() === today.getFullYear()
    );
  }

  /**
   * Checks if a date falls on a weekend.
   * @param {Date} date - The date to check
   * @returns {boolean}
   */
  isWeekend(date) {
    const day = date.getDay();
    return day === 0 || day === 6;
  }

  /**
   * Gets the short weekday name for a date.
   * @param {Date} date - The date
   * @returns {string}
   */
  dayName(date) {
    return date.toLocaleDateString(undefined, { weekday: "short" });
  }

  /**
   * Gets the day number for a date.
   * @param {Date} date - The date
   * @returns {number}
   */
  dayNum(date) {
    return date.getDate();
  }

  /**
   * Gets raw events for a member from the eventsByMember map.
   * @param {Object} member - The member object
   * @returns {Array<Object>} Array of raw event objects
   */
  #getMemberEvents(member) {
    return this.eventsByMember[member.id] || [];
  }

  /**
   * Gets events for a specific member within the current view period,
   * transformed for display.
   * @param {Object} member - The member object
   * @returns {Array<Object>} Array of event objects with display properties
   */
  @bind
  eventsForMember(member) {
    const viewStart = new Date(this.startDate);
    viewStart.setHours(0, 0, 0, 0);
    const viewEnd = new Date(viewStart.getTime() + DAYS * MS_PER_DAY);

    return this.#getMemberEvents(member)
      .filter((e) => {
        const from = new Date(e.from);
        const to = e.to ? new Date(e.to) : from;
        return from < viewEnd && to >= viewStart;
      })
      .map((e) => {
        const from = new Date(e.from);
        from.setHours(0, 0, 0, 0);
        const to = e.to ? new Date(e.to) : new Date(e.from);
        to.setHours(23, 59, 59, 999);

        const startCol = Math.max(
          0,
          Math.floor((from - viewStart) / MS_PER_DAY)
        );
        const endCol = Math.min(
          DAYS - 1,
          Math.floor((to - viewStart) / MS_PER_DAY)
        );
        const span = endCol - startCol + 1;

        const cleanMessage = stripEventTypeHashtag(stripHtml(e.message));
        const firstSentence = cleanMessage
          .split(/[.!?\n]/)[0]
          .trim()
          .slice(0, 50);

        const maxSpan = DAYS - startCol;
        const clippedSpan = Math.min(span, maxSpan);
        const isSingleDay = clippedSpan === 1;

        return {
          ...e,
          message: cleanMessage,
          style: htmlSafe(
            `left: calc(${MEMBER_COL_WIDTH}px + ${startCol} * (100% - ${MEMBER_COL_WIDTH}px) / ${DAYS} + 2px); width: calc(${clippedSpan} * (100% - ${MEMBER_COL_WIDTH}px) / ${DAYS} - 4px);`
          ),
          emoji: EVENT_EMOJIS[e.type] || EVENT_EMOJIS.default,
          label: isSingleDay ? "" : firstSentence,
          isSingleDay,
        };
      });
  }

  /**
   * Navigates the calendar by a number of weeks.
   * @param {number} weeks - Number of weeks to navigate (negative for past)
   */
  @action
  async navigate(weeks) {
    this.startDate = new Date(
      this.startDate.getTime() + weeks * 7 * MS_PER_DAY
    );
    await this.#loadData();
  }

  /**
   * Navigates to the current week.
   */
  @action
  async goToday() {
    this.startDate = this.#mondayOfWeek(new Date());
    await this.#loadData();
  }

  /**
   * Updates the search query from input event.
   * @param {Event} e - The input event
   */
  @action
  updateSearch(e) {
    this.searchQuery = e.target.value;
  }

  /**
   * Selects a group and reloads data.
   * @param {string|null} groupName - The group name to select
   */
  @action
  async selectGroup(groupName) {
    this.selectedGroup = groupName;
    await this.#loadData();

    const url = groupName ? `/availability/${groupName}` : "/availability";
    this.router.replaceWith(url);
  }

  async #loadData() {
    try {
      const params = new URLSearchParams();

      if (this.selectedGroupName) {
        params.set("group_name", this.selectedGroupName);
      }

      const startDate = this.startDate.toISOString().split("T")[0];
      const endDate = new Date(this.startDate.getTime() + DAYS * MS_PER_DAY)
        .toISOString()
        .split("T")[0];
      params.set("start_date", startDate);
      params.set("end_date", endDate);

      const data = await ajax(`/availability.json?${params.toString()}`);
      if (data.error) {
        this.error = data.error;
      } else {
        this.members = data.members || [];
        this.eventsByMember = data.events_by_member || {};
        this.groups = data.groups || [];
      }
    } catch {
      this.error = "failed_to_load";
    } finally {
      this.loading = false;
    }
  }

  #mondayOfWeek(date) {
    const d = new Date(date);
    const day = d.getDay();
    const diff = d.getDate() - day + (day === 0 ? -6 : 1);
    d.setDate(diff);
    d.setHours(0, 0, 0, 0);
    return d;
  }

  <template>
    {{#if this.loading}}
      <div class="loading-container">{{i18n "loading"}}</div>
    {{else if this.error}}
      <div class="error-container">
        {{#if (eq this.error "no_topic_configured")}}
          {{i18n "discourse_post_event.team_availability.no_topic_configured"}}
        {{else}}
          {{i18n "discourse_post_event.team_availability.failed_to_load"}}
        {{/if}}
      </div>
    {{else}}
      <div class="team-availability-calendar">
        <div class="controls">
          <div class="nav">
            <DButton
              @action={{this.goToday}}
              @label="discourse_post_event.team_availability.today"
              class="btn-primary"
            />
            <DButton
              @action={{fn this.navigate -1}}
              @icon="chevron-left"
              class="btn-default"
            />
            <span class="date-range">{{this.dateRange}}</span>
            <DButton
              @action={{fn this.navigate 1}}
              @icon="chevron-right"
              class="btn-default"
            />
          </div>
          <div class="filters">
            <ComboBox
              @value={{this.selectedGroupName}}
              @content={{this.groupOptions}}
              @onChange={{this.selectGroup}}
              @options={{hash
                none="discourse_post_event.team_availability.all_groups"
              }}
              class="group-select"
            />
            <input
              type="text"
              class="search-input"
              placeholder={{i18n
                "discourse_post_event.team_availability.search"
              }}
              value={{this.searchQuery}}
              {{on "input" this.updateSearch}}
            />
          </div>
        </div>

        <div class="calendar-grid">
          <div class="header-row">
            <div class="header-cell member-col"></div>
            {{#each this.dates as |date|}}
              <div
                class={{concatClass
                  "header-cell"
                  (if (this.isToday date) "today")
                  (if (this.isWeekend date) "weekend")
                }}
              >
                <div class="day-name">{{this.dayName date}}</div>
                <div class="day-num">{{this.dayNum date}}</div>
              </div>
            {{/each}}
          </div>

          {{#each this.filteredMembers as |member|}}
            <div class="member-row">
              <div class="member-cell">
                <UserInfo @user={{member}} @size="small" />
              </div>
              {{#each this.dates as |date|}}
                <div
                  class={{concatClass
                    "day-cell"
                    (if (this.isToday date) "today")
                    (if (this.isWeekend date) "weekend")
                  }}
                ></div>
              {{/each}}
              {{#each (this.eventsForMember member) as |event|}}
                {{#if event.post_url}}
                  <a
                    href={{event.post_url}}
                    class={{concatClass
                      "event-bar"
                      (if event.isSingleDay "--single-day")
                      event.type
                    }}
                    style={{event.style}}
                    title={{event.message}}
                  >
                    <span class="event-emoji">{{event.emoji}}</span>
                    {{#if event.label}}
                      <span class="event-label">{{event.label}}</span>
                    {{/if}}
                  </a>
                {{else}}
                  <div
                    class={{concatClass
                      "event-bar"
                      (if event.isSingleDay "--single-day")
                      event.type
                    }}
                    style={{event.style}}
                    title={{event.message}}
                  >
                    <span class="event-emoji">{{event.emoji}}</span>
                    {{#if event.label}}
                      <span class="event-label">{{event.label}}</span>
                    {{/if}}
                  </div>
                {{/if}}
              {{/each}}
            </div>
          {{/each}}
        </div>
      </div>
    {{/if}}
  </template>
}
