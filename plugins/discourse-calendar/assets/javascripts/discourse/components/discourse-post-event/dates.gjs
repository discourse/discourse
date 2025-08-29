import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import loadRRule from "discourse/lib/load-rrule";
import { applyLocalDates } from "discourse/lib/local-dates";
import { cook } from "discourse/lib/text";

export default class DiscoursePostEventDates extends Component {
  @service siteSettings;
  @service currentUser;

  @tracked htmlDates = "";

  get timezone() {
    return this.args.event.timezone || "UTC";
  }

  get startsAtFormat() {
    return this._buildFormat(this.args.currentEventStart, {
      includeYear: !this.isSameYear(this.args.currentEventStart),
      includeTime:
        this.hasTime(this.args.currentEventStart) || this.isSingleDayEvent,
    });
  }

  get endsAtFormat() {
    if (this.isSingleDayEvent) {
      return "LT";
    }

    return this._buildFormat(this.args.currentEventEnd, {
      includeYear:
        !this.isSameYear(this.args.currentEventEnd) ||
        !this.isSameYear(
          this.args.currentEventEnd,
          this.args.currentEventStart
        ),
      includeTime: this.hasTime(this.args.currentEventEnd),
    });
  }

  _buildFormat(date, { includeYear, includeTime }) {
    const formatParts = ["ddd, MMM D"];
    if (includeYear) {
      formatParts.push("YYYY");
    }

    const dateString = formatParts.join(", ");
    const timeString = includeTime ? " LT" : "";

    return `\u0022${dateString}${timeString}\u0022`;
  }

  get isSingleDayEvent() {
    return this.args.currentEventStart.isSame(this.args.currentEventEnd, "day");
  }

  get datesBBCode() {
    const dates = [];

    dates.push(
      this.buildDateBBCode({
        date: this.args.currentEventStart,
        format: this.startsAtFormat,
        range: !!this.args.currentEventEnd && "from",
      })
    );

    if (this.args.currentEventEnd) {
      dates.push(
        this.buildDateBBCode({
          date: this.args.currentEventEnd,
          format: this.endsAtFormat,
          range: "to",
        })
      );
    }

    return dates;
  }

  isSameYear(date1, date2) {
    return date1.isSame(date2 || moment(), "year");
  }

  hasTime(date) {
    return date.hour() || date.minute();
  }

  buildDateBBCode({ date, format, range }) {
    const bbcode = {
      date: date.format("YYYY-MM-DD"),
      time: date.format("HH:mm"),
      format,
      timezone: date.tz(),
      postId: this.args.event.id,
    };

    if (this.args.event.showLocalTime) {
      // For showLocalTime, set displayedTimezone to the event's timezone
      // so the time is displayed in the event's timezone
      bbcode.displayedTimezone = this.args.event.timezone;
    } else {
      bbcode.displayedTimezone =
        this.currentUser?.user_option?.timezone || "UTC";
    }

    if (range) {
      bbcode.range = range;
    }

    const content = Object.entries(bbcode)
      .map(([key, value]) => `${key}=${value}`)
      .join(" ");

    return `[${content}]`;
  }

  @action
  async computeDates(element) {
    if (this.args.expiredAndRecurring) {
      return;
    }

    this.rrule = await loadRRule();

    if (this.siteSettings.discourse_local_dates_enabled) {
      const result = await cook(this.datesBBCode.join("<span> → </span>"));
      this.htmlDates = htmlSafe(result.toString());

      schedule("afterRender", () => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        applyLocalDates(
          element.querySelectorAll(
            `[data-post-id="${this.args.event.id}"].discourse-local-date`
          ),
          this.siteSettings,
          this.currentUser?.user_option?.timezone
        );
      });
    } else {
      let dates = `${this.args.currentEventStart.format(this.startsAtFormat)}`;
      if (this.args.currentEventEnd) {
        dates += ` → ${moment(this.args.currentEventEnd).format(this.endsAtFormat)}`;
      }
      this.htmlDates = htmlSafe(dates);
    }
  }

  <template>
    <section
      data-event-id={{@event.id}}
      class="event__section event-dates"
      {{didInsert this.computeDates}}
    >
      {{icon "clock"}}
      {{#if @expiredAndRecurring}}
        -
      {{else}}
        {{this.htmlDates}}
      {{/if}}
    </section>
  </template>
}
