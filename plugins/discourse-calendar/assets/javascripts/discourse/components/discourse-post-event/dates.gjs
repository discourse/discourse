import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import discourseLater from "discourse/lib/later";
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

  get startsAt() {
    return (
      this.args.currentEventStart ??
      moment(this.args.event.startsAt).tz(this.timezone)
    );
  }

  get endsAt() {
    const currentEventEnd = this.args.currentEventEnd;
    const eventEndsAt = this.args.event.endsAt;

    return (
      currentEventEnd ??
      (eventEndsAt ? moment(eventEndsAt).tz(this.timezone) : null)
    );
  }

  get startsAtFormat() {
    const includeYear = !this.isSameYear(this.startsAt);
    const includeTime = this.hasTime(this.startsAt) || this.isSingleDayEvent;
    return this._buildFormat(this.startsAt, { includeYear, includeTime });
  }

  get endsAtFormat() {
    if (this.isSingleDayEvent) {
      return "LT";
    }

    const endsAt = this.endsAt;
    const includeYear =
      !this.isSameYear(endsAt) || !this.isSameYear(endsAt, this.startsAt);
    const includeTime = this.hasTime(endsAt);

    return this._buildFormat(endsAt, { includeYear, includeTime });
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

    const startDate = this.buildDateBBCode({
      date: this.startsAt,
      format: this.startsAtFormat,
      range: !!this.endsAt && "from",
    });

    dates.push(startDate);

    if (this.endsAt) {
      const endDate = this.buildDateBBCode({
        date: this.endsAt,
        format: this.endsAtFormat,
        range: "to",
      });
      dates.push(endDate);
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
    if (this.args.expiredAndRecurring) {
      return;
    }

    this.rrule = await loadRRule();

    if (this.siteSettings.discourse_local_dates_enabled) {
      const bbcode = this.datesBBCode.join("<span> → </span>");
      const result = await cook(bbcode);
      this.htmlDates = htmlSafe(result.toString());

      // doesn’t work reliably without discourseLater
      discourseLater(() => {
        schedule("afterRender", () => {
          if (this.isDestroying || this.isDestroyed) {
            return;
          }

          const localDateElements = element.querySelectorAll(
            `[data-post-id="${this.args.event.id}"].discourse-local-date`
          );
          applyLocalDates(
            localDateElements,
            this.siteSettings,
            this.currentUser?.user_option?.timezone
          );
        });
      });
    } else {
      let dates = `${this.startsAt.format(this.startsAtFormat)}`;
      if (this.endsAt) {
        const endFormatted = moment(this.endsAt).format(this.endsAtFormat);
        dates += ` → ${endFormatted}`;
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
