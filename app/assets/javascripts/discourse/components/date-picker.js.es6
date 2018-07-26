/* global Pikaday:true */
import loadScript from "discourse/lib/load-script";
import {
  default as computed,
  on
} from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNames: ["date-picker-wrapper"],
  _picker: null,

  @on("didInsertElement")
  _loadDatePicker() {
    const input = this.$(".date-picker")[0];
    const container = $("#" + this.get("containerId"))[0];

    loadScript("/javascripts/pikaday.js").then(() => {
      Ember.run.next(() => {
        let default_opts = {
          field: input,
          container: container || this.$()[0],
          bound: container === undefined,
          format: "YYYY-MM-DD",
          firstDay: 1,
          i18n: {
            previousMonth: I18n.t("dates.previous_month"),
            nextMonth: I18n.t("dates.next_month"),
            months: moment.months(),
            weekdays: moment.weekdays(),
            weekdaysShort: moment.weekdaysShort()
          },
          onSelect: date => {
            const formattedDate = moment(date).format("YYYY-MM-DD");

            if (this.attrs.onSelect) {
              this.attrs.onSelect(formattedDate);
            }

            if (!this.element || this.isDestroying || this.isDestroyed) return;

            this.set("value", formattedDate);
          }
        };

        this._picker = new Pikaday(_.merge(default_opts, this._opts()));
      });
    });
  },

  @on("willDestroyElement")
  _destroy() {
    if (this._picker) {
      this._picker.destroy();
    }
    this._picker = null;
  },

  @computed()
  placeholder() {
    return I18n.t("dates.placeholder");
  },

  _opts() {
    return null;
  }
});
