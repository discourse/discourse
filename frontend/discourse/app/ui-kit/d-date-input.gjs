/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component, { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { schedule } from "@ember/runloop";
import { waitForPromise } from "@ember/test-waiters";
import { classNames } from "@ember-decorators/component";
import { on as onEvent } from "@ember-decorators/object";
import { Promise } from "rsvp";
import { i18n } from "discourse-i18n";

function isInputDateSupported() {
  const input = document.createElement("input");
  const value = "a";
  input.setAttribute("type", "date");
  input.setAttribute("value", value);
  return input.value !== value;
}

@classNames("d-date-input")
export default class DDateInput extends Component {
  date = null;
  useNativePicker = isInputDateSupported();
  _picker = null;

  @computed("site.mobileView")
  get inputType() {
    return this.useNativePicker ? "date" : "text";
  }

  click(event) {
    event.stopPropagation();
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    schedule("afterRender", () => {
      if (!this.element || this.isDestroying || this.isDestroyed) {
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

    if (this._picker) {
      this._picker.setMinDate(this.relativeDate);
    }

    if (this._picker && !this.date) {
      this._picker.setDate(null);
    }
  }

  async _loadPikadayPicker(container) {
    const { default: Pikaday } = await waitForPromise(import("pikaday"));

    const defaultOptions = {
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

    const picker = new Pikaday({ ...defaultOptions, ...this._opts() });
    const pikadaySetMinDate = picker.setMinDate.bind(picker);
    picker.setMinDate = (date) =>
      pikadaySetMinDate(date ? moment(date).toDate() : null);

    return picker;
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
      picker.min = date ? moment(date).format("YYYY-MM-DD") : "";
    };

    if (this.date) {
      picker.setDate(this.date);
    }

    if (this.relativeDate) {
      picker.setMinDate(this.relativeDate);
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

  @onEvent("willDestroyElement")
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

  _toggleHasValueClass(value) {
    const input = this.element.querySelector(".date-picker");
    if (!input) {
      return;
    }

    if (value) {
      input.classList.add("--has-value");
    } else {
      input.classList.remove("--has-value");
    }
  }

  @action
  onChangeDate(event) {
    this._toggleHasValueClass(event.target.value);
    this._handleSelection(event.target.value);
  }

  <template>
    <Input
      @type={{this.inputType}}
      class="date-picker"
      placeholder={{this.placeholder}}
      @value={{readonly this.value}}
      id={{this.inputId}}
      {{on "input" this.onChangeDate}}
      ...attributes
    />

    {{#unless this.useGlobalPickerContainer}}
      <div class="picker-container"></div>
    {{/unless}}
  </template>
}
