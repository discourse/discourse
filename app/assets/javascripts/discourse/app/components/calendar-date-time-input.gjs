import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { waitForPromise } from "@ember/test-waiters";
import { isEmpty } from "@ember/utils";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class CalendarDateTimeInput extends Component {
  _timeFormat = this.args.timeFormat || "HH:mm:ss";
  _dateFormat = this.args.dateFormat || "YYYY-MM-DD";
  _dateTimeFormat = this.args.dateTimeFormat || "YYYY-MM-DD HH:mm:ss";
  _picker = null;

  @tracked _time;
  @tracked _date;

  @action
  setupInternalDateTime() {
    this._time = this.args.time;
    this._date = this.args.date;
  }

  @action
  setupPikaday(element) {
    this.#setupPicker(element).then((picker) => {
      this._picker = picker;
    });
  }

  @action
  onChangeTime(event) {
    this._time = event.target.value;
    this.args.onChangeTime(this._time);
  }

  @action
  changeDate() {
    if (moment(this.args.date, this._dateFormat).isValid()) {
      this._date = this.args.date;
      this._picker.setDate(
        // using the format YYYY-MM-DD returns the previous day for some timezones
        moment.utc(this._date).format("YYYY/MM/DD"),
        true
      );
    } else {
      this._date = null;
      this._picker.setDate(null);
    }
  }

  @action
  changeTime() {
    if (isEmpty(this.args.time)) {
      this._time = null;
      return;
    }

    if (/^(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$/.test(this.args.time)) {
      this._time = this.args.time;
    }
  }

  @action
  changeMinDate() {
    if (
      this.args.minDate &&
      moment(this.args.minDate, this._dateFormat).isValid()
    ) {
      this._picker.setMinDate(
        moment(this.args.minDate, this._dateFormat).toDate()
      );
    } else {
      this._picker.setMinDate(null);
    }
  }

  async #setupPicker(element) {
    const { default: Pikaday } = await waitForPromise(import("pikaday"));

    const options = {
      field: element.querySelector(".fake-input"),
      container: element.querySelector(
        `#picker-container-${this.args.datePickerId}`
      ),
      bound: false,
      format: "YYYY-MM-DD",
      reposition: false,
      firstDay: 1,
      setDefaultDate: true,
      keyboardInput: false,
      i18n: {
        previousMonth: i18n("dates.previous_month"),
        nextMonth: i18n("dates.next_month"),
        months: moment.months(),
        weekdays: moment.weekdays(),
        weekdaysShort: moment.weekdaysMin(),
      },
      onSelect: (date) => {
        const formattedDate = moment(date).format("YYYY-MM-DD");
        this.args.onChangeDate(formattedDate);
      },
    };

    return new Pikaday(options);
  }

  <template>
    <div
      class="calendar-date-time-input"
      {{didInsert this.setupInternalDateTime}}
      {{didInsert this.setupPikaday}}
      {{didUpdate this.changeMinDate @minDate}}
      {{didUpdate this.changeDate @date}}
      {{didUpdate this.changeTime @time}}
    >
      <Input class="fake-input" />

      <div class="date-picker" id="picker-container-{{@datePickerId}}"></div>

      <div class="time-pickers">
        {{icon "far-clock"}}
        <Input
          maxlength={{5}}
          placeholder="hh:mm"
          @type="time"
          @value={{this._time}}
          class="time-picker"
          {{on "input" this.onChangeTime}}
        />
      </div>
    </div>
  </template>
}
