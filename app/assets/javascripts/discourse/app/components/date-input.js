import { Promise } from "rsvp";
import I18n from "I18n";
import { schedule } from "@ember/runloop";
import { action } from "@ember/object";
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

  click(event) {
    event.stopPropagation();
  },

  didInsertElement() {
    this._super(...arguments);

    schedule("afterRender", () => {
      if (!this.element || this.isDestroying || this.isDestroying) {
        return;
      }

      let promise;
      const container = document.getElementById(this.containerId);

      if (this.site.mobileView) {
        promise = this._loadNativePicker(container);
      } else {
        promise = this._loadPikadayPicker(container);
      }

      promise.then(picker => {
        this._picker = picker;

        if (this._picker && this.date) {
          this._picker.setDate(moment(this.date).toDate(), true);
        }
      });
    });
  },

  didUpdateAttrs() {
    this._super(...arguments);

    if (this._picker && this.date) {
      this._picker.setDate(moment(this.date).toDate(), true);
    }

    if (this._picker && this.relativeDate) {
      this._picker.setMinDate(moment(this.relativeDate).toDate(), true);
    }

    if (this._picker && !this.date) {
      this._picker.setDate(null);
    }
  },

  _loadPikadayPicker(container) {
    return loadScript("/javascripts/pikaday.js").then(() => {
      let defaultOptions = {
        field: this.element.querySelector(".date-picker"),
        container: container || this.element.querySelector(".picker-container"),
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

      if (this.relativeDate) {
        defaultOptions = Object.assign({}, defaultOptions, {
          minDate: moment(this.relativeDate).toDate()
        });
      }

      return new Pikaday(Object.assign({}, defaultOptions, this._opts()));
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
      picker.value = moment(date).format("YYYY-MM-DD");
    };
    picker.setMinDate = date => {
      picker.min = date;
    };

    if (this.date) {
      picker.setDate(this.date);
    }

    return Promise.resolve(picker);
  },

  _handleSelection(value) {
    if (!this.element || this.isDestroying || this.isDestroyed) return;

    if (this.onChange) {
      this.onChange(value ? moment(value) : null);
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
  },

  @action
  onChangeDate(event) {
    this._handleSelection(event.target.value);
  }
});
