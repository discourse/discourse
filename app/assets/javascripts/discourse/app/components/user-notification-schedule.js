import EmberObject, { action } from "@ember/object";
import Component from "@ember/component";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";

const DAYS = [
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
  "sunday",
];

const Day = EmberObject.extend({
  id: null,
  startTimeOptions: null,
  model: null,

  @action
  onChangeStartTime(val) {
    this.startingTimeChangedForDay(val);
  },

  @action
  onChangeEndTime(val) {
    this.set(`model.user_notification_schedule.day_${this.id}_end_time`, val);
  },

  @discourseComputed(
    "model.user_notification_schedule.day_{0,1,2,3,4,5,6}_start_time"
  )
  startTimeValue(schedule) {
    return schedule[`day_${this.id}_start_time`];
  },

  @discourseComputed(
    "model.user_notification_schedule.day_{0,1,2,3,4,5,6}_start_time"
  )
  endTimeOptions(schedule) {
    return this.buildEndTimeOptionsFor(schedule[`day_${this.id}_start_time`]);
  },

  @discourseComputed(
    "model.user_notification_schedule.day_{0,1,2,3,4,5,6}_end_time"
  )
  endTimeValue(schedule) {
    return schedule[`day_${this.id}_end_time`];
  },

  startingTimeChangedForDay(val) {
    val = parseInt(val, 10);
    this.model.set(`user_notification_schedule.day_${this.id}_start_time`, val);
    if (
      val !== "-1" &&
      this.model.user_notification_schedule[`day_${this.id}_end_time`] <= val
    ) {
      this.model.set(
        `user_notification_schedule.day_${this.id}_end_time`,
        val + 30
      );
    }
  },

  buildEndTimeOptionsFor(startTime) {
    startTime = parseInt(startTime, 10);
    if (startTime === -1) {
      return null;
    }
    return this.buildTimeOptions(startTime + 30, {
      includeNone: false,
      showMidnight: true,
    });
  },
});

export default Component.extend({
  days: null,

  didInsertElement() {
    this._super(...arguments);
    this.set(
      "startTimeOptions",
      this.buildTimeOptions(0, {
        includeNone: true,
        showMidnight: false,
      })
    );

    this.set("days", []);

    DAYS.forEach((day, index) => {
      this.days.pushObject(
        Day.create({
          id: index,
          day,
          model: this.model,
          buildTimeOptions: this.buildTimeOptions,
          startTimeOptions: this.startTimeOptions,
        })
      );
    });
  },

  buildTimeOptions(startAt, opts = { includeNone: false, showMidnight: true }) {
    let timeOptions = [];

    if (opts.includeNone) {
      timeOptions.push({
        name: I18n.t("user.notification_schedule.none"),
        value: -1,
      });
    }

    for (let timeInMin = startAt; timeInMin <= 1440; timeInMin += 30) {
      let hours = Math.floor(timeInMin / 60);
      let minutes = timeInMin % 60;

      if (minutes === 0) {
        minutes = "00";
      }
      if (hours === 24) {
        if (opts.showMidnight) {
          timeOptions.push({
            name: I18n.t("user.notification_schedule.midnight"),
            value: 1440,
          });
        }
        break;
      }
      timeOptions.push({
        name: moment().set("hour", hours).set("minute", minutes).format("LT"),
        value: timeInMin,
      });
    }
    return timeOptions;
  },
});
