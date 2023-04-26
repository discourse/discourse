import discourseComputed, { on } from "discourse-common/utils/decorators";
import { isBlank } from "@ember/utils";
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
    const usesHours = Object.hasOwn(this.attrs, "durationHours");
    const usesMinutes = Object.hasOwn(this.attrs, "durationMinutes");

    if (usesHours && usesMinutes) {
      throw new Error(
        "relative-time needs initial duration in hours OR minutes, both are not supported"
      );
    }

    if (usesHours) {
      this._setInitialDurationFromHours(this.durationHours);
    } else {
      this._setInitialDurationFromMinutes(this.durationMinutes);
    }
  },

  @on("init")
  setHiddenIntervals() {
    this.hiddenIntervals = this.hiddenIntervals || [];
  },

  _roundedDuration(duration) {
    let rounded = parseFloat(duration.toFixed(2));

    // showing 2.00 instead of just 2 in the input is weird
    if (rounded % 1 === 0) {
      return parseInt(rounded, 10);
    }

    return rounded;
  },

  _setInitialDurationFromHours(hours) {
    if (hours === null) {
      this.setProperties({
        duration: hours,
        selectedInterval: "hours",
      });
    } else if (hours >= 8760) {
      this.setProperties({
        duration: this._roundedDuration(hours / 365 / 24),
        selectedInterval: "years",
      });
    } else if (hours >= 730) {
      this.setProperties({
        duration: this._roundedDuration(hours / 30 / 24),
        selectedInterval: "months",
      });
    } else if (hours >= 24) {
      this.setProperties({
        duration: this._roundedDuration(hours / 24),
        selectedInterval: "days",
      });
    } else if (hours < 1) {
      this.setProperties({
        duration: this._roundedDuration(hours * 60),
        selectedInterval: "mins",
      });
    } else {
      this.setProperties({
        duration: hours,
        selectedInterval: "hours",
      });
    }
  },

  _setInitialDurationFromMinutes(mins) {
    if (mins >= 525600) {
      this.setProperties({
        duration: this._roundedDuration(mins / 365 / 60 / 24),
        selectedInterval: "years",
      });
    } else if (mins >= 43800) {
      this.setProperties({
        duration: this._roundedDuration(mins / 30 / 60 / 24),
        selectedInterval: "months",
      });
    } else if (mins >= 1440) {
      this.setProperties({
        duration: this._roundedDuration(mins / 60 / 24),
        selectedInterval: "days",
      });
    } else if (mins >= 60) {
      this.setProperties({
        duration: this._roundedDuration(mins / 60),
        selectedInterval: "hours",
      });
    } else {
      this.setProperties({
        duration: mins,
        selectedInterval: "mins",
      });
    }
  },

  @discourseComputed("selectedInterval")
  durationMin(selectedInterval) {
    return selectedInterval === "mins" ? 1 : 0.1;
  },

  @discourseComputed("selectedInterval")
  durationStep(selectedInterval) {
    return selectedInterval === "mins" ? 1 : 0.05;
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
      {
        id: "years",
        name: I18n.t("relative_time_picker.years", { count }),
      },
    ].filter((interval) => !this.hiddenIntervals.includes(interval.id));
  },

  @discourseComputed("selectedInterval", "duration")
  calculatedMinutes(interval, duration) {
    if (isBlank(duration)) {
      return null;
    }
    duration = parseFloat(duration);

    let mins = 0;

    switch (interval) {
      case "mins":
        // we round up here in case the user manually inputted a step < 1
        mins = Math.ceil(duration);
        break;
      case "hours":
        mins = duration * 60;
        break;
      case "days":
        mins = duration * 60 * 24;
        break;
      case "months":
        mins = duration * 60 * 24 * 30; // less accurate because of varying days in months
        break;
      case "years":
        mins = duration * 60 * 24 * 365; // least accurate because of varying days in months/years
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
