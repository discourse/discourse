/* global Pikaday:true */
import loadScript from "discourse/lib/load-script";
import { on } from "ember-addons/ember-computed-decorators";

export default Em.Component.extend({
  classNames: ["date-picker-wrapper"],
  _picker: null,

  @on("didInsertElement")
  _loadDatePicker() {
    const input = this.$(".date-picker")[0];

    loadScript("/javascripts/pikaday.js").then(() => {
      let default_opts = {
        field: input,
        container: this.$()[0],
        format: "YYYY-MM-DD",
        defaultDate: moment().add(1, "day").toDate(),
        minDate: new Date(),
        firstDay: moment.localeData().firstDayOfWeek(),
        i18n: {
          previousMonth: I18n.t('dates.previous_month'),
          nextMonth: I18n.t('dates.next_month'),
          months: moment.months(),
          weekdays: moment.weekdays(),
          weekdaysShort: moment.weekdaysShort()
        },
        onSelect: date => this.set("value", moment(date).format("YYYY-MM-DD"))
      };

      this._picker = new Pikaday(_.merge(default_opts, this._opts()));
    });
  },

  @on("willDestroyElement")
  _destroy() {
    this._picker = null;
  },

  _opts() {
    return null;
  }

});
