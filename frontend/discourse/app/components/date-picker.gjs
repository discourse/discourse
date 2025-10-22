/* eslint-disable ember/no-classic-components */
import Component, { Input } from "@ember/component";
import { computed } from "@ember/object";
import { schedule } from "@ember/runloop";
import { waitForPromise } from "@ember/test-waiters";
import { classNames } from "@ember-decorators/component";
import { on } from "@ember-decorators/object";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

const DATE_FORMAT = "YYYY-MM-DD";

@classNames("date-picker-wrapper")
export default class DatePicker extends Component {
  value = null;
  minDate = null;
  maxDate = null;
  _picker = null;

  @discourseComputed("site.mobileView")
  inputType(mobileView) {
    return mobileView ? "date" : "text";
  }

  @on("didInsertElement")
  _loadDatePicker() {
    if (this.site.mobileView) {
      this._loadNativePicker();
    } else {
      const container = document.getElementById(this.containerId);
      this._loadPikadayPicker(container);
    }
  }

  async _loadPikadayPicker(container) {
    const { default: Pikaday } = await waitForPromise(import("pikaday"));

    schedule("afterRender", () => {
      const options = {
        field: this.element.querySelector(".date-picker"),
        container: container || null,
        bound: container === null,
        format: DATE_FORMAT,
        firstDay: 1,
        minDate: this.minDate,
        maxDate: this.maxDate,
        i18n: {
          previousMonth: i18n("dates.previous_month"),
          nextMonth: i18n("dates.next_month"),
          months: moment.months(),
          weekdays: moment.weekdays(),
          weekdaysShort: moment.weekdaysMin(),
        },
        onSelect: (date) => this._handleSelection(date),
      };

      this._picker = new Pikaday(Object.assign(options, this._opts()));

      if (this.value) {
        this._picker.setDate(moment(this.value).toDate(), true);
      } else {
        this._picker.setDate(null);
      }
    });
  }

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
  }

  _handleSelection(value) {
    const formattedDate = moment(value).format(DATE_FORMAT);

    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    if (this.onSelect) {
      this.onSelect(formattedDate);
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

  <template>
    <Input
      @type={{this.inputType}}
      class="date-picker"
      placeholder={{this.placeholder}}
      @value={{this.value}}
      autocomplete="off"
      ...attributes
    />
  </template>
}
