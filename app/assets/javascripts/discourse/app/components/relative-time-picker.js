import discourseComputed, { on } from "discourse-common/utils/decorators";

import Component from "@ember/component";
import I18n from "I18n";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",
  selectedInterval: "mins",
  durationMinutes: null,
  durationHours: null,
  duration: null,
  hiddenIntervals: null,

  @on("init")
  cloneDuration() {
    let mins = this.durationMinutes;
    let hours = this.durationHours;

    if (hours && mins) {
      throw new Error(
        "relative-time needs initial duration in hours OR minutes, both are not supported"
      );
    }

    if (hours) {
      this._setInitialDurationFromHours(hours);
    } else {
      this._setInitialDurationFromMinutes(mins);
    }
  },

  @on("init")
  setHiddenIntervals() {
    this.hiddenIntervals = this.hiddenIntervals || [];
  },

  _setInitialDurationFromHours(hours) {
    if (hours >= 730) {
      this.setProperties({
        duration: Math.floor(hours / 30 / 24),
        selectedInterval: "months",
      });
    } else if (hours >= 24) {
      this.setProperties({
        duration: Math.floor(hours / 24),
        selectedInterval: "days",
      });
    } else {
      this.setProperties({
        duration: hours,
        selectedInterval: "hours",
      });
    }
  },

  _setInitialDurationFromMinutes(mins) {
    if (mins >= 43800) {
      this.setProperties({
        duration: Math.floor(mins / 30 / 60 / 24),
        selectedInterval: "months",
      });
    } else if (mins >= 1440) {
      this.setProperties({
        duration: Math.floor(mins / 60 / 24),
        selectedInterval: "days",
      });
    } else if (mins >= 60) {
      this.setProperties({
        duration: Math.floor(mins / 60),
        selectedInterval: "hours",
      });
    } else {
      this.setProperties({
        duration: mins,
        selectedInterval: "mins",
      });
    }
  },

  @discourseComputed("duration")
  intervals(duration) {
    const count = duration ? parseFloat(duration) : 0;

    return [
      {
        id: "mins",
        name: I18n.t("relative_time_picker.minutes", { count }),
      },
      {
        id: "hours",
        name: I18n.t("relative_time_picker.hours", { count }),
      },
      {
        id: "days",
        name: I18n.t("relative_time_picker.days", { count }),
      },
      {
        id: "months",
        name: I18n.t("relative_time_picker.months", { count }),
      },
    ].filter((interval) => !this.hiddenIntervals.includes(interval.id));
  },

  @discourseComputed("selectedInterval", "duration")
  calculatedMinutes(interval, duration) {
    duration = parseFloat(duration);

    let mins = 0;

    switch (interval) {
      case "mins":
        mins = duration;
        break;
      case "hours":
        mins = duration * 60;
        break;
      case "days":
        mins = duration * 60 * 24;
        break;
      case "months":
        mins = duration * 60 * 24 * 30; // least accurate because of varying days in months
        break;
    }

    return mins;
  },

  @action
  onChangeInterval(newInterval) {
    this.set("selectedInterval", newInterval);
    if (this.onChange) {
      this.onChange(this.calculatedMinutes);
    }
  },

  @action
  onChangeDuration() {
    if (this.onChange) {
      this.onChange(this.calculatedMinutes);
    }
  },
});
