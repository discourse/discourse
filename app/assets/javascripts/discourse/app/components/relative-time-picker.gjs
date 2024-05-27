import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isBlank } from "@ember/utils";
import I18n from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default class RelativeTimePicker extends Component {
  _roundedDuration(duration) {
    const rounded = parseFloat(duration.toFixed(2));

    // showing 2.00 instead of just 2 in the input is weird
    return rounded % 1 === 0 ? parseInt(rounded, 10) : rounded;
  }

  get duration() {
    if (this.args.durationMinutes !== undefined) {
      return this._durationFromMinutes;
    } else {
      return this._durationFromHours;
    }
  }

  get selectedInterval() {
    if (this.args.durationMinutes !== undefined) {
      return this._intervalFromMinutes;
    } else {
      return this._intervalFromHours;
    }
  }

  get _durationFromHours() {
    if (this.args.durationHours === null) {
      return this.args.durationHours;
    } else if (this.args.durationHours >= 8760) {
      return this._roundedDuration(this.args.durationHours / 365 / 24);
    } else if (this.args.durationHours >= 730) {
      return this._roundedDuration(this.args.durationHours / 30 / 24);
    } else if (this.args.durationHours >= 24) {
      return this._roundedDuration(this.args.durationHours / 24);
    } else if (this.args.durationHours >= 1) {
      return this.args.durationHours;
    } else {
      return this._roundedDuration(this.args.durationHours * 60);
    }
  }

  get _intervalFromHours() {
    if (this.args.durationHours === null) {
      return "hours";
    } else if (this.args.durationHours >= 8760) {
      return "years";
    } else if (this.args.durationHours >= 730) {
      return "months";
    } else if (this.args.durationHours >= 24) {
      return "days";
    } else if (this.args.durationHours < 1) {
      return "mins";
    } else {
      return "hours";
    }
  }

  get _durationFromMinutes() {
    if (this.args.durationMinutes >= 525600) {
      return this._roundedDuration(this.args.durationMinutes / 365 / 60 / 24);
    } else if (this.args.durationMinutes >= 43800) {
      return this._roundedDuration(this.args.durationMinutes / 30 / 60 / 24);
    } else if (this.args.durationMinutes >= 1440) {
      return this._roundedDuration(this.args.durationMinutes / 60 / 24);
    } else if (this.args.durationMinutes >= 60) {
      return this._roundedDuration(this.args.durationMinutes / 60);
    } else {
      return this.args.durationMinutes;
    }
  }

  get _intervalFromMinutes() {
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

  get durationMin() {
    return this.selectedInterval === "mins" ? 1 : 0.1;
  }

  get durationStep() {
    return this.selectedInterval === "mins" ? 1 : 0.05;
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

  calculateMinutes(duration, interval) {
    if (isBlank(duration) || isNaN(duration)) {
      return null;
    }

    duration = parseFloat(duration);

    switch (interval) {
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
    const minutes = this.calculateMinutes(this.duration, interval);
    this.args.onChange?.(minutes);
  }

  @action
  onChangeDuration(event) {
    const minutes = this.calculateMinutes(
      event.target.value,
      this.selectedInterval
    );
    this.args.onChange?.(minutes);
  }

  <template>
    <div class="relative-time-picker">
      <input
        {{on "change" this.onChangeDuration}}
        type="number"
        min={{this.durationMin}}
        step={{this.durationStep}}
        value={{this.duration}}
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
