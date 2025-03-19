import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { fromSeconds, toSeconds } from "discourse/helpers/slow-mode";
import { extractError } from "discourse/lib/ajax-error";
import { timeShortcuts } from "discourse/lib/time-shortcut";
import Topic from "discourse/models/topic";
import { i18n } from "discourse-i18n";

const SLOW_MODE_OPTIONS = [
  {
    id: "600",
    name: i18n("topic.slow_mode_update.durations.10_minutes"),
  },
  {
    id: "900",
    name: i18n("topic.slow_mode_update.durations.15_minutes"),
  },
  {
    id: "1800",
    name: i18n("topic.slow_mode_update.durations.30_minutes"),
  },
  {
    id: "2700",
    name: i18n("topic.slow_mode_update.durations.45_minutes"),
  },
  {
    id: "3600",
    name: i18n("topic.slow_mode_update.durations.1_hour"),
  },
  {
    id: "7200",
    name: i18n("topic.slow_mode_update.durations.2_hours"),
  },
  {
    id: "14400",
    name: i18n("topic.slow_mode_update.durations.4_hours"),
  },
  {
    id: "28800",
    name: i18n("topic.slow_mode_update.durations.8_hours"),
  },
  {
    id: "43200",
    name: i18n("topic.slow_mode_update.durations.12_hours"),
  },
  {
    id: "86400",
    name: i18n("topic.slow_mode_update.durations.24_hours"),
  },
  {
    id: "custom",
    name: i18n("topic.slow_mode_update.durations.custom"),
  },
];

export default class EditSlowMode extends Component {
  @service currentUser;

  @tracked selectedSlowMode;
  @tracked hours;
  @tracked minutes;
  @tracked seconds;
  @tracked saveDisabled = false;
  @tracked flash;

  constructor() {
    super(...arguments);
    const currentDuration = parseInt(
      this.args.model.topic.slow_mode_seconds,
      10
    );
    if (currentDuration) {
      const selectedDuration = this.slowModes.find(
        (mode) => mode.id === currentDuration.toString()
      );

      if (selectedDuration) {
        this.selectedSlowMode = currentDuration.toString();
      } else {
        this.selectedSlowMode = "custom";
      }

      this._setFromSeconds(currentDuration);
    }
  }

  get slowModes() {
    return SLOW_MODE_OPTIONS;
  }

  get saveButtonLabel() {
    return this.args.model.topic.slow_mode_seconds &&
      this.args.model.topic.slow_mode_seconds !== 0
      ? "topic.slow_mode_update.update"
      : "topic.slow_mode_update.enable";
  }

  get timeShortcuts() {
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
  }

  get showCustomSelect() {
    return this.selectedSlowMode === "custom";
  }

  get durationIsSet() {
    return this.hours || this.minutes || this.seconds;
  }

  @action
  async enableSlowMode() {
    this.saveDisabled = true;
    const seconds = toSeconds(
      this._parseValue(this.hours),
      this._parseValue(this.minutes),
      this._parseValue(this.seconds)
    );

    try {
      await Topic.setSlowMode(
        this.args.model.topic.id,
        seconds,
        this.args.model.topic.slow_mode_enabled_until
      );
      this.args.model.topic.set("slow_mode_seconds", seconds);
      this.args.closeModal();
    } catch {
      this.flash = i18n("generic_error");
    } finally {
      this.saveDisabled = false;
    }
  }

  @action
  async disableSlowMode() {
    this.saveDisabled = true;
    try {
      await Topic.setSlowMode(this.args.model.topic.id, 0);
      this.args.model.topic.set("slow_mode_seconds", 0);
      this.args.closeModal();
    } catch (e) {
      this.flash = extractError(e);
    } finally {
      this.saveDisabled = false;
    }
  }

  @action
  setSlowModeDuration(duration) {
    if (duration !== "custom") {
      let seconds = parseInt(duration, 10);
      this._setFromSeconds(seconds);
    }

    this.selectedSlowMode = duration;
  }

  _setFromSeconds(seconds) {
    const { hours, minutes, seconds: componentSeconds } = fromSeconds(seconds);
    this.hours = hours;
    this.minutes = minutes;
    this.seconds = componentSeconds;
  }

  _parseValue(value) {
    return parseInt(value, 10) || 0;
  }
}
