import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "I18n";
import Topic from "discourse/models/topic";

export default Controller.extend(ModalFunctionality, {
  selectedSlowMode: null,
  hours: null,
  minutes: null,
  seconds: null,
  saveDisabled: false,

  slowModes: [
    {
      id: "900",
      name: I18n.t("topic.slow_mode_update.intervals.15_minutes"),
    },
    {
      id: "3600",
      name: I18n.t("topic.slow_mode_update.intervals.1_hour"),
    },
    {
      id: "14400",
      name: I18n.t("topic.slow_mode_update.intervals.4_hours"),
    },
    {
      id: "86400",
      name: I18n.t("topic.slow_mode_update.intervals.1_day"),
    },
    {
      id: "604800",
      name: I18n.t("topic.slow_mode_update.intervals.1_week"),
    },
    {
      id: "custom",
      name: I18n.t("topic.slow_mode_update.intervals.custom")
    }
  ],

  onShow() {
    const currentInterval = parseInt(this.model.slow_mode_seconds, 10);

    if (currentInterval) {
      const selectedInterval = this.slowModes.find((mode) => {
        return mode.id === currentInterval.toString();
      })

      if (selectedInterval) {
        this.set("selectedSlowMode", currentInterval.toString());
      } else {
        this.set("selectedSlowMode", "custom");
      }

      this._setFromSeconds(currentInterval);
    }
  },

  @discourseComputed("selectedSlowMode")
  showCustomSelect(mode) {
    return mode === "custom";
  },

  @discourseComputed("hours", "minutes", "seconds")
  submitDisabled(hours, minutes, seconds) {
    return this.saveDisabled || !(this.hours || this.minutes || this.seconds);
  },

  _setFromSeconds(seconds) {
    let initialSeconds = seconds

    let hours = initialSeconds / 3600
    if (hours >= 1) {
      initialSeconds = initialSeconds - (3600 * hours)
    } else {
      hours = 0
    }

    let minutes = initialSeconds / 60
    if (minutes >= 1) {
      initialSeconds = initialSeconds - (60 * minutes)  
    } else {
      minutes = 0
    }

    this.setProperties({
      hours: hours,
      minutes: minutes,
      seconds: initialSeconds
    })
  },

  _toSeconds() {
    const hoursAsSeconds = parseInt(this.hours, 10) * 60 * 60
    const minutesAsSeconds = parseInt(this.minutes, 10) * 60

    return parseInt(this.seconds, 10) + hoursAsSeconds + minutesAsSeconds
  },

  actions: {
    setSlowModeInterval(interval) {
      if (interval !== "custom") {
        let seconds = parseInt(interval, 10);
        
        this._setFromSeconds(seconds);
      }

      this.set("selectedSlowMode", interval);
    },

    enableSlowMode() {
      this.set("saveDisabled", true);
      const seconds = this._toSeconds()
      Topic.setSlowMode(this.model.id, seconds).finally(() => {
        this.set("model.slow_mode_seconds", seconds);
        this.set("saveDisabled", false);
      });
    },

    disableSlowMode() {
      this.set("saveDisabled", true);
      Topic.setSlowMode(this.model.id, 0).finally(() => { 
        this.set("model.slow_mode_seconds", 0);
        this.set("saveDisabled", false);
      });
    },
  }
})


