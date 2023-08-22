import { action, computed } from "@ember/object";
import Component from "@ember/component";

export default Component.extend({
  classNames: ["d-date-time-input"],
  date: null,
  relativeDate: null,
  showTime: true,
  clearable: false,

  hours: computed("date", "showTime", function () {
    return this.date && this.get("showTime") ? this.date.hours() : null;
  }),

  minutes: computed("date", "showTime", function () {
    return this.date && this.get("showTime") ? this.date.minutes() : null;
  }),

  @action
  onClear() {
    this.onChange(null);
  },

  @action
  onChangeTime(time) {
    if (this.onChange) {
      const date = this.date
        ? this.date
        : this.relativeDate
        ? this.relativeDate
        : moment.tz(this.resolvedTimezone);

      this.onChange(
        moment.tz(
          {
            year: date.year(),
            month: date.month(),
            day: date.date(),
            hours: time.hours,
            minutes: time.minutes,
          },
          this.resolvedTimezone
        )
      );
    }
  },

  @action
  onChangeDate(date) {
    if (!date) {
      this.onClear();
      return;
    }

    this.onChange?.(
      moment.tz(
        {
          year: date.year(),
          month: date.month(),
          day: date.date(),
          hours: this.hours || 0,
          minutes: this.minutes || 0,
        },
        this.resolvedTimezone
      )
    );
  },

  @computed("timezone")
  get resolvedTimezone() {
    return this.timezone || moment.tz.guess();
  },
});
