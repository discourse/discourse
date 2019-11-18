import Component from "@ember/component";
import { computed } from "@ember/object";

export default Component.extend({
  classNames: ["d-date-time-input"],
  date: null,
  showTime: true,

  _hours: computed("date", function() {
    return this.date && this.showTime ? this.date.getHours() : null;
  }),

  _minutes: computed("date", function() {
    return this.date && this.showTime ? this.date.getMinutes() : null;
  }),

  actions: {
    onChangeTime(time) {
      if (this.onChange) {
        const year = this.date.getFullYear();
        const month = this.date.getMonth();
        const day = this.date.getDate();
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
