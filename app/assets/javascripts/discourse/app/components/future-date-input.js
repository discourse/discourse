import Component from "@ember/component";
import { action } from "@ember/object";
import { and, empty, equal } from "@ember/object/computed";
import { CLOSE_STATUS_TYPE } from "discourse/controllers/edit-topic-timer";
import buildTimeframes from "discourse/lib/timeframes-builder";
import I18n from "I18n";
import { FORMAT } from "select-kit/components/future-date-input-selector";

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
      const dateTime = moment(this.input);
      const closestTimeframe = this.findClosestTimeframe(dateTime);
      if (closestTimeframe) {
        this.set("selection", closestTimeframe.id);
      } else {
        this.setProperties({
          selection: "pick_date_and_time",
          _date: dateTime.format("YYYY-MM-DD"),
          _time: dateTime.format("HH:mm"),
        });
      }
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

  findClosestTimeframe(dateTime) {
    const now = moment();

    const futureDateInputSelectorOptions = {
      now,
      day: now.day(),
      includeWeekend: this.includeWeekend,
      includeFarFuture: this.includeFarFuture,
      includeDateTime: this.includeDateTime,
      canScheduleNow: this.includeNow || false,
      canScheduleToday: 24 - now.hour() > 6,
    };

    return buildTimeframes(futureDateInputSelectorOptions).find((tf) => {
      const tfDateTime = tf.when(
        moment(),
        this.statusType !== CLOSE_STATUS_TYPE ? 8 : 18
      );

      if (tfDateTime) {
        const diff = tfDateTime.diff(dateTime);
        return 0 <= diff && diff < 60 * 1000;
      }
    });
  },
});
