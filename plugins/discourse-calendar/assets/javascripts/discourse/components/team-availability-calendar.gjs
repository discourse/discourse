import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
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

const EVENT_STYLES = {
  leave: { color: "#22c55e", emoji: "🏖️" },
  sick: { color: "#ef4444", emoji: "🤒" },
  "family-reasons": { color: "#f59e0b", emoji: "👨‍👩‍👧" },
  work: { color: "#3b82f6", emoji: "💼" },
  "public-holiday": { color: "#8b5cf6", emoji: "🎉" },
  "authorized-absence": { color: "#6366f1", emoji: "✅" },
  "special-leave": { color: "#14b8a6", emoji: "⭐" },
  "parental-leave": { color: "#ec4899", emoji: "👶" },
  default: { color: "#0ea5e9", emoji: "📅" },
};

function detectEventType(message) {
  const match = (message || "").match(/#([\w-]+)/);
  if (match) {
    let tag = match[1].toLowerCase();
    // Handle special-leave(AU) -> special-leave
    if (tag.includes("(")) {
      tag = tag.split("(")[0];
    }
    if (EVENT_STYLES[tag]) {
      return { type: tag, ...EVENT_STYLES[tag] };
    }
  }
  return { type: "default", ...EVENT_STYLES.default };
}

function stripHtml(str) {
  return (str || "").replace(/<[^>]*>/g, "").trim();
}

/**
 * @component TeamAvailabilityCalendar
 *
 * Displays a calendar grid showing team member availability.
 */
export default class TeamAvailabilityCalendar extends Component {
  @tracked loading = true;
  @tracked error = null;
  @tracked startDate = this.#mondayOfWeek(new Date());
  @tracked members = [];
  @tracked events = [];
  @tracked groups = [];
  @tracked searchQuery = "";
  @tracked selectedGroup = null;

  constructor() {
    super(...arguments);
    this.#loadData();
  }

  get selectedGroupName() {
    return this.selectedGroup ?? this.args.groupName ?? null;
  }

  get groupOptions() {
    return this.groups.map((g) => ({
      id: g.name,
      name: g.full_name || g.name,
    }));
  }

  get dates() {
    const dates = [];
    for (let i = 0; i < DAYS; i++) {
      dates.push(new Date(this.startDate.getTime() + i * MS_PER_DAY));
    }
    return dates;
  }

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

  get dateRange() {
    const end = new Date(this.startDate.getTime() + (DAYS - 1) * MS_PER_DAY);
    const fmt = (d) =>
      d.toLocaleDateString(undefined, { month: "short", day: "numeric" });
    return `${fmt(this.startDate)} - ${fmt(end)}`;
  }

  isToday(date) {
    const today = new Date();
    return (
      date.getDate() === today.getDate() &&
      date.getMonth() === today.getMonth() &&
      date.getFullYear() === today.getFullYear()
    );
  }

  isWeekend(date) {
    const day = date.getDay();
    return day === 0 || day === 6;
  }

  dayName(date) {
    return date.toLocaleDateString(undefined, { weekday: "short" });
  }

  dayNum(date) {
    return date.getDate();
  }

  @bind
  eventsForMember(member) {
    const viewStart = new Date(this.startDate);
    viewStart.setHours(0, 0, 0, 0);
    const viewEnd = new Date(viewStart.getTime() + DAYS * MS_PER_DAY);

    return this.events
      .filter((e) => {
        const isUser =
          e.user_id === member.id || e.user_ids?.includes(member.id);
        if (!isUser) {
          return false;
        }
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

        const cleanMessage = stripHtml(e.message);
        const typeStyle = detectEventType(cleanMessage);
        const firstSentence = cleanMessage
          .split(/[.!?\n]/)[0]
          .trim()
          .slice(0, 50);

        const maxSpan = DAYS - startCol;
        const clippedSpan = Math.min(span, maxSpan);

        const isSingleDay = clippedSpan === 1;

        return {
          ...e,
          style: htmlSafe(
            `left: calc(${MEMBER_COL_WIDTH}px + ${startCol} * (100% - ${MEMBER_COL_WIDTH}px) / ${DAYS} + 2px); width: calc(${clippedSpan} * (100% - ${MEMBER_COL_WIDTH}px) / ${DAYS} - 4px); background: ${typeStyle.color};`
          ),
          emoji: typeStyle.emoji,
          label: isSingleDay ? "" : firstSentence,
          isSingleDay,
        };
      });
  }

  @action
  navigate(weeks) {
    this.startDate = new Date(
      this.startDate.getTime() + weeks * 7 * MS_PER_DAY
    );
  }

  @action
  goToday() {
    this.startDate = this.#mondayOfWeek(new Date());
  }

  @action
  updateSearch(e) {
    this.searchQuery = e.target.value;
  }

  @action
  async selectGroup(groupName) {
    this.selectedGroup = groupName;
    const url = groupName ? `/availability/${groupName}` : "/availability";
    history.replaceState(null, "", url);
    await this.#loadData();
  }

  async #loadData() {
    try {
      const url = this.selectedGroupName
        ? `/availability.json?group_name=${encodeURIComponent(this.selectedGroupName)}`
        : "/availability.json";
      const data = await ajax(url);
      if (data.error) {
        this.error = data.error;
      } else {
        this.members = data.members || [];
        this.events = data.events || [];
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
                      (if event.isSingleDay "single-day")
                    }}
                    style={{event.style}}
                    title={{event.message}}
                  >
                    <span class="event-emoji">{{event.emoji}}</span>
                    {{#if event.label}}<span
                        class="event-label"
                      >{{event.label}}</span>{{/if}}
                  </a>
                {{else}}
                  <div
                    class={{concatClass
                      "event-bar"
                      (if event.isSingleDay "single-day")
                    }}
                    style={{event.style}}
                    title={{event.message}}
                  >
                    <span class="event-emoji">{{event.emoji}}</span>
                    {{#if event.label}}<span
                        class="event-label"
                      >{{event.label}}</span>{{/if}}
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
