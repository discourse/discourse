import { fromSeconds, toSeconds } from "discourse/helpers/slow-mode";
import Controller from "@ember/controller";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import Topic from "discourse/models/topic";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { equal, or } from "@ember/object/computed";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { timeShortcuts } from "discourse/lib/time-shortcut";

export default Controller.extend(ModalFunctionality, {
  selectedSlowMode: null,
  hours: null,
  minutes: null,
  seconds: null,
  saveDisabled: false,
  showCustomSelect: equal("selectedSlowMode", "custom"),
  durationIsSet: or("hours", "minutes", "seconds"),

  init() {
    this._super(...arguments);

    this.set("slowModes", [
      {
        id: "600",
        name: I18n.t("topic.slow_mode_update.durations.10_minutes"),
      },
      {
        id: "900",
        name: I18n.t("topic.slow_mode_update.durations.15_minutes"),
      },
      {
        id: "1800",
        name: I18n.t("topic.slow_mode_update.durations.30_minutes"),
      },
      {
        id: "2700",
        name: I18n.t("topic.slow_mode_update.durations.45_minutes"),
      },
      {
        id: "3600",
        name: I18n.t("topic.slow_mode_update.durations.1_hour"),
      },
      {
        id: "7200",
        name: I18n.t("topic.slow_mode_update.durations.2_hours"),
      },
      {
        id: "14400",
        name: I18n.t("topic.slow_mode_update.durations.4_hours"),
      },
      {
        id: "28800",
        name: I18n.t("topic.slow_mode_update.durations.8_hours"),
      },
      {
        id: "43200",
        name: I18n.t("topic.slow_mode_update.durations.12_hours"),
      },
      {
        id: "86400",
        name: I18n.t("topic.slow_mode_update.durations.24_hours"),
      },
      {
        id: "custom",
        name: I18n.t("topic.slow_mode_update.durations.custom"),
      },
    ]);
  },

  onShow() {
    const currentDuration = parseInt(this.model.slow_mode_seconds, 10);

    if (currentDuration) {
      const selectedDuration = this.slowModes.find((mode) => {
        return mode.id === currentDuration.toString();
      });

      if (selectedDuration) {
        this.set("selectedSlowMode", currentDuration.toString());
      } else {
        this.set("selectedSlowMode", "custom");
      }

      this._setFromSeconds(currentDuration);
    }
  },

  @discourseComputed(
    "saveDisabled",
    "durationIsSet",
    "model.slow_mode_enabled_until"
  )
  submitDisabled(saveDisabled, durationIsSet, enabledUntil) {
    return saveDisabled || !durationIsSet || !enabledUntil;
  },

  @discourseComputed("model.slow_mode_seconds")
  slowModeEnabled(slowModeSeconds) {
    return slowModeSeconds && slowModeSeconds !== 0;
  },

  @discourseComputed("slowModeEnabled")
  saveButtonLabel(slowModeEnabled) {
    return slowModeEnabled
      ? "topic.slow_mode_update.update"
      : "topic.slow_mode_update.enable";
  },

  @discourseComputed
  timeShortcuts() {
    const timezone = this.currentUser.user_option.timezone;
    const shortcuts = timeShortcuts(timezone);

    const nextWeek = shortcuts.monday();
    nextWeek.label = "time_shortcut.next_week";

    return [
      shortcuts.laterToday(),
      shortcuts.tomorrow(),
      shortcuts.twoDays(),
      nextWeek,
      shortcuts.twoWeeks(),
      shortcuts.nextMonth(),
      shortcuts.twoMonths(),
    ];
  },

  _setFromSeconds(seconds) {
    this.setProperties(fromSeconds(seconds));
  },

  _parseValue(value) {
    return parseInt(value, 10) || 0;
  },

  @action
  setSlowModeDuration(duration) {
    if (duration !== "custom") {
      let seconds = parseInt(duration, 10);

      this._setFromSeconds(seconds);
    }

    this.set("selectedSlowMode", duration);
  },

  @action
  enableSlowMode() {
    this.set("saveDisabled", true);

    const seconds = toSeconds(
      this._parseValue(this.hours),
      this._parseValue(this.minutes),
      this._parseValue(this.seconds)
    );

    Topic.setSlowMode(
      this.model.id,
      seconds,
      this.model.slow_mode_enabled_until
    )
      .catch(popupAjaxError)
      .then(() => {
        this.set("model.slow_mode_seconds", seconds);
        this.send("closeModal");
      })
      .finally(() => this.set("saveDisabled", false));
  },

  @action
  disableSlowMode() {
    this.set("saveDisabled", true);
    Topic.setSlowMode(this.model.id, 0)
      .catch(popupAjaxError)
      .then(() => {
        this.set("model.slow_mode_seconds", 0);
        this.send("closeModal");
      })
      .finally(() => this.set("saveDisabled", false));
  },
});
