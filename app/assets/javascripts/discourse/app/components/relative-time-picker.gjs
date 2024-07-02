import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { isBlank } from "@ember/utils";
import { eq } from "truth-helpers";
import I18n from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

function roundDuration(duration) {
  let rounded = parseFloat(duration.toFixed(1));
  rounded = Math.round(rounded * 2) / 2;

  // showing 2.00 instead of just 2 in the input is weird
  return rounded % 1 === 0 ? parseInt(rounded, 10) : rounded;
}

export default class RelativeTimePicker extends Component {
  @tracked inputValue = this.initialInputValue;
  @tracked interval = this.initialInterval;
  @tracked duration = this.calculateMinutes();

  get initialInputValue() {
    const { durationMinutes, durationHours } = this.args;

    if (isBlank(durationMinutes) && isBlank(durationHours)) {
      return;
    }

    if (durationMinutes) {
      if (durationMinutes >= 525600) {
        return roundDuration(durationMinutes / 365 / 60 / 24);
      } else if (durationMinutes >= 43800) {
        return roundDuration(durationMinutes / 30 / 60 / 24);
      } else if (durationMinutes >= 1440) {
        return roundDuration(durationMinutes / 60 / 24);
      } else if (durationMinutes >= 60) {
        return roundDuration(durationMinutes / 60);
      } else {
        return durationMinutes;
      }
    }

    if (durationHours >= 8760) {
      return roundDuration(durationHours / 365 / 24);
    } else if (durationHours >= 730) {
      return roundDuration(durationHours / 30 / 24);
    } else if (durationHours >= 24) {
      return roundDuration(durationHours / 24);
    } else if (durationHours >= 1) {
      return durationHours;
    } else {
      return roundDuration(this.args.durationHours * 60);
    }
  }

  get initialInterval() {
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
  }

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

  calculateMinutes() {
    if (isNaN(this.inputValue)) {
      return null;
    }

    switch (this.interval) {
      case "mins":
        // we round up here in case the user manually inputted a step < 1
        return Math.ceil(this.inputValue);
      case "hours":
        return this.inputValue * 60;
      case "days":
        return this.inputValue * 60 * 24;
      case "months":
        return this.inputValue * 60 * 24 * 30; // less accurate because of varying days in months
      case "years":
        return this.inputValue * 60 * 24 * 365; // least accurate because of varying days in months/years
    }
  }

  @action
  initValues() {
    this.interval = this.initialInterval;
    this.inputValue = this.initialInputValue;
    this.duration = this.calculateMinutes();
  }

  @action
  onChangeDuration(event) {
    this.inputValue = isBlank(event.target.value)
      ? null
      : parseFloat(event.target.value);
    this.duration = this.calculateMinutes();
    this.args.onChange?.(this.duration);
  }

  @action
  onChangeInterval(interval) {
    this.interval = interval;
    this.args.onChange?.(this.calculateMinutes());
  }

  <template>
    <div class="relative-time-picker">
      <input
        {{didUpdate this.initValues @durationMinutes @durationHours}}
        {{on "change" this.onChangeDuration}}
        type="number"
        min={{if (eq this.interval "mins") 1 0.5}}
        step={{if (eq this.interval "mins") 1 0.5}}
        value={{this.inputValue}}
        id={{@id}}
        class="relative-time-duration"
      />
      <ComboBox
        @content={{this.intervals}}
        @value={{this.interval}}
        @onChange={{this.onChangeInterval}}
        class="relative-time-intervals"
      />
    </div>
  </template>
}
