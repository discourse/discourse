import { schedule } from "@ember/runloop";
import Component from "@ember/component";
/* global Pikaday:true */
import loadScript from "discourse/lib/load-script";
import discourseComputed, { on } from "discourse-common/utils/decorators";

const DATE_FORMAT = "YYYY-MM-DD";

export default Component.extend({
  classNames: ["date-picker-wrapper"],
  _picker: null,
  value: null,

  @discourseComputed("site.mobileView")
  inputType(mobileView) {
    return mobileView ? "date" : "text";
  },

  @on("didInsertElement")
  _loadDatePicker() {
    if (this.site.mobileView) {
      this._loadNativePicker();
    } else {
      const container = document.getElementById(this.containerId);
      this._loadPikadayPicker(container);
    }
  },

  _loadPikadayPicker(container) {
    loadScript("/javascripts/pikaday.js").then(() => {
      schedule("afterRender", () => {
        const options = {
          field: this.element.querySelector(".date-picker"),
          container: container || null,
          bound: container === null,
          format: DATE_FORMAT,
          firstDay: 1,
          i18n: {
            previousMonth: I18n.t("dates.previous_month"),
            nextMonth: I18n.t("dates.next_month"),
            months: moment.months(),
            weekdays: moment.weekdays(),
            weekdaysShort: moment.weekdaysMin()
          },
          onSelect: date => this._handleSelection(date)
        };

        this._picker = new Pikaday(Object.assign(options, this._opts()));
      });
    });
  },

  _loadNativePicker() {
    const picker = this.element.querySelector("input.date-picker");
    picker.onchange = () => this._handleSelection(picker.value);
    picker.hide = () => {
      /* do nothing for native */
    };
    picker.destroy = () => {
      /* do nothing for native */
    };
    this._picker = picker;
  },

  _handleSelection(value) {
    const formattedDate = moment(value).format(DATE_FORMAT);

    if (!this.element || this.isDestroying || this.isDestroyed) return;

    if (this.onSelect) {
      this.onSelect(formattedDate);
    }
  },

  @on("willDestroyElement")
  _destroy() {
    if (this._picker) {
      this._picker.destroy();
      this._picker = null;
    }
  },

  @discourseComputed()
  placeholder() {
    return I18n.t("dates.placeholder");
  },

  _opts() {
    return null;
  }
});
