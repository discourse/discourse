import Component from "@ember/component";
export default Component.extend({
  classNames: ["d-date-time-input"],
  date: null,
  showTime: true,

  _hours: Ember.computed("date", function() {
    return this.date ? this.date.getHours() : null;
  }),

  _minutes: Ember.computed("date", function() {
    return this.date ? this.date.getMinutes() : null;
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
