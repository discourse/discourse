import { and, empty, equal } from "@ember/object/computed";
import { action } from "@ember/object";
import Component from "@ember/component";
import { FORMAT } from "select-kit/components/future-date-input-selector";
import I18n from "I18n";

export default Component.extend({
  selection: null,
  includeDateTime: true,
  isCustom: equal("selection", "pick_date_and_time"),
  displayDateAndTimePicker: and("includeDateTime", "isCustom"),
  displayLabel: null,
  labelClasses: null,
  timeInputDisabled: empty("_date"),

  _date: null,
  _time: null,

  init() {
    this._super(...arguments);

    if (this.input) {
      const datetime = moment(this.input);
      this.setProperties({
        selection: "pick_date_and_time",
        _date: datetime.format("YYYY-MM-DD"),
        _time: datetime.format("HH:mm"),
      });
    }
  },

  didReceiveAttrs() {
    this._super(...arguments);

    if (this.label) {
      this.set("displayLabel", I18n.t(this.label));
    }
  },

  @action
  onChangeDate(date) {
    if (!date) {
      this.set("time", null);
    }

    this._dateTimeChanged(date, this.time);
  },

  @action
  onChangeTime(time) {
    if (this._date) {
      this._dateTimeChanged(this._date, time);
    }
  },

  _dateTimeChanged(date, time) {
    time = time ? ` ${time}` : "";
    const dateTime = moment(`${date}${time}`);

    if (dateTime.isValid()) {
      this.attrs.onChangeInput &&
        this.attrs.onChangeInput(dateTime.format(FORMAT));
    } else {
      this.attrs.onChangeInput && this.attrs.onChangeInput(null);
    }
  },
});
