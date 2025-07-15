import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import { applyLocalDates } from "discourse/lib/local-dates";
import { cook } from "discourse/lib/text";

export default class DiscoursePostEventDates extends Component {
  @service siteSettings;

  @tracked htmlDates = "";

  get startsAt() {
    return moment(this.args.event.startsAt).tz(this.timezone);
  }

  get endsAt() {
    return (
      this.args.event.endsAt && moment(this.args.event.endsAt).tz(this.timezone)
    );
  }

  get timezone() {
    return this.args.event.timezone || "UTC";
  }

  get startsAtFormat() {
    return this._buildFormat(this.startsAt, {
      includeYear: !this.isSameYear(this.startsAt),
      includeTime: this.hasTime(this.startsAt) || this.isSingleDayEvent,
    });
  }

  get endsAtFormat() {
    if (this.isSingleDayEvent) {
      return "LT";
    }

    return this._buildFormat(this.endsAt, {
      includeYear:
        !this.isSameYear(this.endsAt) ||
        !this.isSameYear(this.endsAt, this.startsAt),
      includeTime: this.hasTime(this.endsAt),
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
    return this.startsAt.isSame(this.endsAt, "day");
  }

  get datesBBCode() {
    const dates = [];

    dates.push(
      this.buildDateBBCode({
        date: this.startsAt,
        format: this.startsAtFormat,
        range: !!this.endsAt && "from",
      })
    );

    if (this.endsAt) {
      dates.push(
        this.buildDateBBCode({
          date: this.endsAt,
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
      timezone: this.timezone,
      hideTimezone: this.args.event.showLocalTime,
    };

    if (this.args.event.showLocalTime) {
      bbcode.displayedTimezone = this.args.event.timezone;
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
    if (this.siteSettings.discourse_local_dates_enabled) {
      const result = await cook(this.datesBBCode.join("<span> → </span>"));
      this.htmlDates = htmlSafe(result.toString());

      next(() => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        applyLocalDates(
          element.querySelectorAll(
            `[data-post-id="${this.args.event.id}"] .discourse-local-date`
          ),
          this.siteSettings
        );
      });
    } else {
      let dates = `${this.startsAt.format(this.startsAtFormat)}`;
      if (this.endsAt) {
        dates += ` → ${moment(this.endsAt).format(this.endsAtFormat)}`;
      }
      this.htmlDates = htmlSafe(dates);
    }
  }

  <template>
    <section class="event__section event-dates" {{didInsert this.computeDates}}>
      {{icon "clock"}}{{this.htmlDates}}</section>
  </template>
}
