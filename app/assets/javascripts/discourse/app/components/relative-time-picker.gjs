import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isBlank } from "@ember/utils";
import { eq } from "truth-helpers";
import I18n from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

function roundedDuration(duration) {
  const rounded = parseFloat(duration.toFixed(2));

  // showing 2.00 instead of just 2 in the input is weird
  return rounded % 1 === 0 ? parseInt(rounded, 10) : rounded;
}

export default class RelativeTimePicker extends Component {
  @tracked selectedInterval = (() => {
    if (this.args.durationMinutes !== undefined) {
      if (this.args.durationMinutes >= 525600) {
        return "years";
      } else if (this.args.durationMinutes >= 43800) {
        return "months";
      } else if (this.args.durationMinutes >= 1440) {
        return "days";
      } else if (this.args.durationMinutes >= 60) {
        return "hours";
      } else {
        return "mins";
      }
    }

    if (this.args.durationHours !== undefined) {
      if (this.args.durationHours >= 8760) {
        return "years";
      } else if (this.args.durationHours >= 730) {
        return "months";
      } else if (this.args.durationHours >= 24) {
        return "days";
      } else if (
        this.args.durationHours >= 1 ||
        this.args.durationHours === null
      ) {
        return "hours";
      } else {
        return "mins";
      }
    }

    return "mins";
  })();

  @tracked duration = (() => {
    const { durationMinutes, durationHours } = this.args;

    if (isBlank(durationMinutes) && isBlank(durationHours)) {
      return;
    }

    if (durationMinutes) {
      if (durationMinutes >= 525600) {
        return roundedDuration(durationMinutes / 365 / 60 / 24);
      } else if (durationMinutes >= 43800) {
        return roundedDuration(durationMinutes / 30 / 60 / 24);
      } else if (durationMinutes >= 1440) {
        return roundedDuration(durationMinutes / 60 / 24);
      } else if (durationMinutes >= 60) {
        return roundedDuration(durationMinutes / 60);
      } else {
        return durationMinutes;
      }
    }

    if (durationHours >= 8760) {
      return roundedDuration(durationHours / 365 / 24);
    } else if (durationHours >= 730) {
      return roundedDuration(durationHours / 30 / 24);
    } else if (durationHours >= 24) {
      return roundedDuration(durationHours / 24);
    } else if (durationHours >= 1) {
      return durationHours;
    } else {
      return roundedDuration(this.args.durationHours * 60);
    }
  })();

  inputValue = this.duration;

  get intervals() {
    const count = this.duration ? parseFloat(this.duration) : 0;

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
    ].filter((interval) => !this.args.hiddenIntervals?.includes(interval.id));
  }

  calculateMinutes(duration) {
    if (isNaN(duration)) {
      return null;
    }

    switch (this.selectedInterval) {
      case "mins":
        // we round up here in case the user manually inputted a step < 1
        return Math.ceil(duration);
      case "hours":
        return duration * 60;
      case "days":
        return duration * 60 * 24;
      case "months":
        return duration * 60 * 24 * 30; // less accurate because of varying days in months
      case "years":
        return duration * 60 * 24 * 365; // least accurate because of varying days in months/years
    }
  }

  @action
  onChangeInterval(interval) {
    this.selectedInterval = interval;
    this.args.onChange?.(this.calculateMinutes(this.inputValue));
  }

  @action
  onChangeDuration(event) {
    this.inputValue = parseFloat(event.target.value);
    this.duration = this.calculateMinutes(this.inputValue);
    this.args.onChange?.(this.duration);
  }

  <template>
    <div class="relative-time-picker">
      <input
        {{on "input" this.onChangeDuration}}
        type="number"
        min={{if (eq this.selectedInterval "mins") 1 0.1}}
        step={{if (eq this.selectedInterval "mins") 1 0.05}}
        value={{this.inputValue}}
        id={{@id}}
        class="relative-time-duration"
      />
      <ComboBox
        @content={{this.intervals}}
        @value={{this.selectedInterval}}
        @onChange={{this.onChangeInterval}}
        class="relative-time-intervals"
      />
    </div>
  </template>
}
