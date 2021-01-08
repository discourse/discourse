import Component from "@ember/component";
import I18n from "I18n";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  startTimeOptions: null,

  didInsertElement() {
    this._super(...arguments);
    this.set(
      "startTimeOptions",
      this.buildTimeOptions(0, {
        includeNone: true,
        showMidnight: false,
      })
    );
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
      let am = timeInMin < 720;
      if (minutes === 0) {
        minutes = "00";
      }
      if (hours === 0) {
        hours = "12";
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
      if (!am && hours !== 12) {
        hours = hours - 12;
      }
      const amPm = I18n.t(
        `user.notification_schedule.${am ? "morning" : "afternoon"}`
      );
      timeOptions.push({
        name: `${hours}:${minutes} ${amPm}`,
        value: timeInMin,
      });
    }
    return timeOptions;
  },

  @action
  startingTimeChangedForDay(dayIndex, val) {
    val = parseInt(val, 10);
    this.model.set(
      `user_notification_schedule.day_${dayIndex}_start_time`,
      val
    );
    if (
      val !== "-1" &&
      this.model.user_notification_schedule[`day_${dayIndex}_end_time`] < val
    ) {
      this.model.set(
        `user_notification_schedule.day_${dayIndex}_end_time`,
        val + 30
      );
    }
  },

  @discourseComputed("model.user_notification_schedule.day_0_start_time")
  day0EndTimeOptions(startTime) {
    return this._buildEndTimeOptionsFor(startTime);
  },

  @discourseComputed("model.user_notification_schedule.day_1_start_time")
  day1EndTimeOptions(startTime) {
    return this._buildEndTimeOptionsFor(startTime);
  },

  @discourseComputed("model.user_notification_schedule.day_2_start_time")
  day2EndTimeOptions(startTime) {
    return this._buildEndTimeOptionsFor(startTime);
  },

  @discourseComputed("model.user_notification_schedule.day_3_start_time")
  day3EndTimeOptions(startTime) {
    return this._buildEndTimeOptionsFor(startTime);
  },

  @discourseComputed("model.user_notification_schedule.day_4_start_time")
  day4EndTimeOptions(startTime) {
    return this._buildEndTimeOptionsFor(startTime);
  },

  @discourseComputed("model.user_notification_schedule.day_5_start_time")
  day5EndTimeOptions(startTime) {
    return this._buildEndTimeOptionsFor(startTime);
  },

  @discourseComputed("model.user_notification_schedule.day_6_start_time")
  day6EndTimeOptions(startTime) {
    return this._buildEndTimeOptionsFor(startTime);
  },

  _buildEndTimeOptionsFor(startTime) {
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
