import Component from "@ember/component";
import { action } from "@ember/object";
import { and, empty, equal } from "@ember/object/computed";
import buildTimeframes from "discourse/lib/timeframes-builder";
import I18n from "I18n";
import { FORMAT } from "select-kit/components/future-date-input-selector";

export default Component.extend({
  selection: null,
  includeDateTime: true,
  isCustom: equal("selection", "custom"),
  displayDateAndTimePicker: and("includeDateTime", "isCustom"),
  displayLabel: null,
  labelClasses: null,
  timeInputDisabled: empty("_date"),
  userTimezone: null,

  _date: null,
  _time: null,

  init() {
    this._super(...arguments);
    this.userTimezone = this.currentUser.resolvedTimezone(this.currentUser);

    if (this.input) {
      const dateTime = moment(this.input);
      const closestTimeframe = this.findClosestTimeframe(dateTime);
      if (closestTimeframe) {
        this.set("selection", closestTimeframe.id);
      } else {
        this.setProperties({
          selection: "custom",
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
    const options = {
      includeWeekend: this.includeWeekend,
      includeFarFuture: this.includeFarFuture,
      includeDateTime: this.includeDateTime,
      canScheduleNow: this.includeNow || false,
    };

    return buildTimeframes(this.userTimezone, options).find((tf) => {
      if (tf.time) {
        const diff = tf.time.diff(dateTime);
        return 0 <= diff && diff < 60 * 1000;
      }
    });
  },
});
