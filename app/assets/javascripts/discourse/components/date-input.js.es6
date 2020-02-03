import { next } from "@ember/runloop";
import Component from "@ember/component";
/* global Pikaday:true */
import loadScript from "discourse/lib/load-script";
import discourseComputed, { on } from "discourse-common/utils/decorators";

export default Component.extend({
  classNames: ["d-date-input"],
  date: null,
  _picker: null,

  @discourseComputed("site.mobileView")
  inputType(mobileView) {
    return mobileView ? "date" : "text";
  },

  @on("didInsertElement")
  _loadDatePicker() {
    const container = this.element.querySelector(`#${this.containerId}`);

    if (this.site.mobileView) {
      this._loadNativePicker(container);
    } else {
      this._loadPikadayPicker(container);
    }

    if (this.date && this._picker) {
      this._picker.setDate(this.date, true);
    }
  },

  didUpdateAttrs() {
    this._super(...arguments);

    if (this._picker && typeof date === "string") {
      const [year, month, day] = this.date.split("-").map(x => parseInt(x, 10));
      this._picker.setDate(new Date(year, month - 1, day), true);
    }
  },

  _loadPikadayPicker(container) {
    loadScript("/javascripts/pikaday.js").then(() => {
      next(() => {
        const default_opts = {
          field: this.element.querySelector(".date-picker"),
          container: container || this.element,
          bound: container === null,
          format: "LL",
          firstDay: 1,
          i18n: {
            previousMonth: I18n.t("dates.previous_month"),
            nextMonth: I18n.t("dates.next_month"),
            months: moment.months(),
            weekdays: moment.weekdays(),
            weekdaysShort: moment.weekdaysShort()
          },
          onSelect: date => this._handleSelection(date)
        };

        this._picker = new Pikaday(Object.assign(default_opts, this._opts()));
        this._picker.setDate(this.date, true);
      });
    });
  },

  _loadNativePicker(container) {
    const wrapper = container || this.element;
    const picker = wrapper.querySelector("input.date-picker");
    picker.onchange = () => this._handleSelection(picker.value);
    picker.hide = () => {
      /* do nothing for native */
    };
    picker.destroy = () => {
      /* do nothing for native */
    };
    picker.setDate = date => {
      picker.value = date;
    };
    this._picker = picker;
  },

  _handleSelection(value) {
    if (!this.element || this.isDestroying || this.isDestroyed) return;

    this._picker && this._picker.hide();

    if (this.onChange) {
      this.onChange(value);
    }
  },

  @on("willDestroyElement")
  _destroy() {
    if (this._picker) {
      this._picker.destroy();
    }
    this._picker = null;
  },

  @discourseComputed()
  placeholder() {
    return I18n.t("dates.placeholder");
  },

  _opts() {
    return null;
  },

  actions: {
    onInput(event) {
      this._picker && this._picker.setDate(event.target.value, true);
    }
  }
});
