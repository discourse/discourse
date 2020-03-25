import Component from "@ember/component";
import { computed } from "@ember/object";

export default Component.extend({
  classNames: ["d-date-time-input"],
  date: null,
  showTime: true,
  clearable: false,

  _hours: computed("date", function() {
    return this.date && this.showTime ? new Date(this.date).getHours() : null;
  }),

  _minutes: computed("date", function() {
    return this.date && this.showTime ? new Date(this.date).getMinutes() : null;
  }),

  actions: {
    onClear() {
      this.onChange(null);
    },

    onChangeTime(time) {
      if (this.onChange) {
        const date = new Date(this.date);
        const year = date.getFullYear();
        const month = date.getMonth();
        const day = date.getDate();
        this.onChange(new Date(year, month, day, time.hours, time.minutes));
      }
    },

    onChangeDate(date) {
      if (this.onChange) {
        const year = date.getFullYear();
        const month = date.getMonth();
        const day = date.getDate();
        this.onChange(
          new Date(year, month, day, this._hours || 0, this._minutes || 0)
        );
      }
    }
  }
});
