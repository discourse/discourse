/* global Pikaday:true */
import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { schedule } from "@ember/runloop";
import { classNames } from "@ember-decorators/component";
import { on } from "@ember-decorators/object";
import { Promise } from "rsvp";
import discourseComputed from "discourse/lib/decorators";
import loadScript from "discourse/lib/load-script";
import { i18n } from "discourse-i18n";

function isInputDateSupported() {
  const input = document.createElement("input");
  const value = "a";
  input.setAttribute("type", "date");
  input.setAttribute("value", value);
  return input.value !== value;
}

@classNames("d-date-input")
export default class DateInput extends Component {
  date = null;
  useNativePicker = isInputDateSupported();
  _picker = null;

  @discourseComputed("site.mobileView")
  inputType() {
    return this.useNativePicker ? "date" : "text";
  }

  click(event) {
    event.stopPropagation();
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    schedule("afterRender", () => {
      if (!this.element || this.isDestroying || this.isDestroying) {
        return;
      }

      let promise;
      const container = document.getElementById(this.containerId);

      if (this.useNativePicker) {
        promise = this._loadNativePicker(container);
      } else {
        promise = this._loadPikadayPicker(container);
      }

      promise.then((picker) => {
        this._picker = picker;

        if (this._picker && this.date) {
          const parsedDate =
            this.date instanceof moment ? this.date : moment(this.date);
          this._picker.setDate(parsedDate, true);
        }
      });
    });
  }

  didUpdateAttrs() {
    super.didUpdateAttrs(...arguments);

    if (this._picker && this.date) {
      const parsedDate =
        this.date instanceof moment ? this.date : moment(this.date);
      this._picker.setDate(parsedDate, true);
    }

    if (this._picker && this.relativeDate) {
      const parsedRelativeDate =
        this.relativeDate instanceof moment
          ? this.relativeDate
          : moment(this.relativeDate);

      this._picker.setMinDate(parsedRelativeDate, true);
    }

    if (this._picker && !this.date) {
      this._picker.setDate(null);
    }
  }

  _loadPikadayPicker(container) {
    return loadScript("/javascripts/pikaday.js").then(() => {
      let defaultOptions = {
        field: this.element.querySelector(".date-picker"),
        container: container || this.element.querySelector(".picker-container"),
        bound: container === null,
        format: "LL",
        firstDay: 1,
        i18n: {
          previousMonth: i18n("dates.previous_month"),
          nextMonth: i18n("dates.next_month"),
          months: moment.months(),
          weekdays: moment.weekdays(),
          weekdaysShort: moment.weekdaysShort(),
        },
        onSelect: (date) => this._handleSelection(date),
      };

      if (this.relativeDate) {
        defaultOptions.minDate = moment(this.relativeDate).toDate();
      }

      return new Pikaday({ ...defaultOptions, ...this._opts() });
    });
  }

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
    picker.setDate = (date) => {
      picker.value = date ? moment(date).format("YYYY-MM-DD") : null;
    };
    picker.setMinDate = (date) => {
      picker.min = date;
    };

    if (this.date) {
      picker.setDate(this.date);
    }

    return Promise.resolve(picker);
  }

  _handleSelection(value) {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    if (this.onChange) {
      this.onChange(value ? moment(value) : null);
    }
  }

  @on("willDestroyElement")
  _destroy() {
    if (this._picker) {
      this._picker.destroy();
      this._picker = null;
    }
  }

  @computed("_placeholder")
  get placeholder() {
    return this._placeholder || i18n("dates.placeholder");
  }

  set placeholder(value) {
    this.set("_placeholder", value);
  }

  _opts() {
    return null;
  }

  @action
  onChangeDate(event) {
    this._handleSelection(event.target.value);
  }
}
