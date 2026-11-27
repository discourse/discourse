import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import moment from "moment";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import formatEventForCalendar from "../lib/format-event-for-calendar.js";
import DiscoursePostEventEvent from "../models/discourse-post-event-event.js";
import FullCalendar from "./full-calendar.gjs";

export default class UpcomingEventsAgenda extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked events = [];
  @tracked error = false;
  @tracked hasEarlier = false;
  @tracked hasLater = false;
  @tracked loading = null;

  #anchor;
  #busy = false;
  #calendar;
  #cursors = {};
  #generation = 0;
  #range;
  #retryDirection = "later";

  willDestroy() {
    this.#generation++;
    super.willDestroy(...arguments);
  }

  @action
  loadEvents() {
    return this.events;
  }

  @action
  onDatesChange(info) {
    this.#calendar = info.view.calendar;
    if (info.view.type === "listYear" && this.#range?.after !== info.startStr) {
      this.#range = { after: info.startStr, before: info.endStr };
      const today = moment()
        .tz(this.currentUser?.user_option?.timezone || moment.tz.guess())
        .startOf("day");
      this.#anchor = today.isBetween(info.start, info.end, undefined, "[)")
        ? today.format()
        : info.startStr;
      this.reset();
    }
    this.args.onDatesChange?.(info);
  }

  @action
  reset() {
    if (!this.#range) {
      return;
    }
    this.#generation++;
    this.#busy = false;
    this.#cursors = {};
    this.events = [];
    this.hasEarlier = false;
    this.hasLater = false;
    this.#load("later", true);
  }

  @action
  retry() {
    return this.#load(this.#retryDirection, this.events.length === 0);
  }

  @action
  showEarlier() {
    if (this.hasEarlier) {
      return this.#load("earlier");
    }
  }

  @action
  showLater() {
    if (this.hasLater) {
      return this.#load("later");
    }
  }

  async #load(direction, initial = false) {
    if (this.#busy) {
      return;
    }
    this.#busy = true;
    const generation = this.#generation;
    const cursor = this.#cursors[direction];
    const firstDay = this.#calendar?.el.querySelector(".fc-list-day");
    const anchorDate = firstDay?.dataset.date;
    const previousTop = firstDay?.getBoundingClientRect().top;
    this.loading = direction;
    this.#retryDirection = direction;
    this.error = false;
    try {
      const result = await ajax("/discourse-post-event/events/agenda", {
        data: {
          ...this.#range,
          anchor: this.#anchor,
          timezone:
            this.currentUser?.user_option?.timezone || moment.tz.guess(),
          direction,
          cursor_time: cursor?.time,
          cursor_id: cursor?.id,
          category_id: this.args.categoryId,
          include_subcategories: this.args.includeSubcategories,
          attending_user: this.args.mine
            ? this.currentUser?.username
            : undefined,
        },
      });
      if (generation !== this.#generation) {
        return;
      }

      const events = new Map(this.events.map((event) => [event.id, event]));
      for (const event of result.events) {
        for (const occurrence of event.occurrences) {
          const id = `${event.id}-${occurrence.starts_at}`;
          events.set(id, {
            ...formatEventForCalendar(
              DiscoursePostEventEvent.create({ ...event, ...occurrence }),
              this.siteSettings.map_events_to_color,
              this.currentUser?.user_option?.timezone
            ),
            id,
          });
        }
      }
      this.events = [...events.values()];
      this.#cursors[direction] = result.next_cursor;
      if (initial || direction === "earlier") {
        this.hasEarlier = result.has_earlier;
      }
      if (initial || direction === "later") {
        this.hasLater = result.has_later;
      }

      if (direction === "earlier" && anchorDate) {
        requestAnimationFrame(() => {
          if (generation === this.#generation) {
            const anchor = this.#calendar?.el.querySelector(
              `.fc-list-day[data-date="${anchorDate}"]`
            );
            if (anchor) {
              window.scrollBy(
                0,
                anchor.getBoundingClientRect().top - previousTop
              );
            }
          }
        });
      }
    } catch {
      if (generation === this.#generation) {
        this.error = true;
      }
    } finally {
      if (generation === this.#generation) {
        this.#busy = false;
        this.loading = null;
      }
    }
  }

  <template>
    <div
      class="upcoming-events-agenda"
      ...attributes
      {{didUpdate this.reset @categoryId @includeSubcategories @mine}}
    >
      {{#if this.error}}
        <p role="alert">{{i18n
            "discourse_post_event.upcoming_events_list.error"
          }}</p>
        <DButton
          @action={{this.retry}}
          @label="discourse_post_event.upcoming_events_list.try_again"
        />
      {{/if}}
      <FullCalendar
        @centerHeaderToolbar={{@centerHeaderToolbar}}
        @customButtons={{@customButtons}}
        @events={{this.events}}
        @height="auto"
        @initialDate={{@initialDate}}
        @initialView="listYear"
        @leftHeaderToolbar={{@leftHeaderToolbar}}
        @onDatesChange={{this.onDatesChange}}
        @onLoadEvents={{this.loadEvents}}
        @rightHeaderToolbar={{@rightHeaderToolbar}}
      >
        {{#if this.hasEarlier}}
          <div class="upcoming-events-agenda__pagination">
            <DButton
              class="upcoming-events-agenda__earlier btn-default"
              @action={{this.showEarlier}}
              @disabled={{this.loading}}
              @icon="chevron-up"
              @label={{if
                this.loading
                "loading"
                "discourse_post_event.upcoming_events.agenda.show_earlier"
              }}
            />
          </div>
        {{/if}}
      </FullCalendar>
      {{#if this.hasLater}}
        <div class="upcoming-events-agenda__pagination">
          <DButton
            class="upcoming-events-agenda__later btn-default"
            @action={{this.showLater}}
            @disabled={{this.loading}}
            @icon="chevron-down"
            @label={{if
              this.loading
              "loading"
              "discourse_post_event.upcoming_events.agenda.show_later"
            }}
          />
        </div>
      {{/if}}
    </div>
  </template>
}
