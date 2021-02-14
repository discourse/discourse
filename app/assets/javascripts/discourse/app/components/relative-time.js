import discourseComputed, { on } from "discourse-common/utils/decorators";

import Component from "@ember/component";
import I18n from "I18n";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",
  selectedInterval: "mins",
  durationMinutes: null,
  duration: null,

  @on("init")
  cloneDuration() {
    let mins = this.durationMinutes;

    if (mins >= 1440) {
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

  @discourseComputed
  intervals() {
    return [
      { id: "mins", name: I18n.t("relative_time.minutes") },
      { id: "hours", name: I18n.t("relative_time.hours") },
      { id: "days", name: I18n.t("relative_time.days") },
      { id: "months", name: I18n.t("relative_time.months") },
    ];
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
