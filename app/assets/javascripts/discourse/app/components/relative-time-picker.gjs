import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isBlank } from "@ember/utils";
import I18n from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default class RelativeTimePicker extends Component {
  @tracked duration;
  @tracked selectedInterval;

  constructor() {
    super(...arguments);

    const usesHours = this.args.durationHours !== undefined;
    const usesMinutes = this.args.durationMinutes !== undefined;

    if (usesHours && usesMinutes) {
      throw new Error(
        "relative-time needs initial duration in hours OR minutes, both are not supported"
      );
    }

    if (usesHours) {
      this._setInitialDurationFromHours();
    } else {
      this._setInitialDurationFromMinutes();
    }
  }

  _roundedDuration(duration) {
    const rounded = parseFloat(duration.toFixed(2));

    // showing 2.00 instead of just 2 in the input is weird
    return rounded % 1 === 0 ? parseInt(rounded, 10) : rounded;
  }

  _setInitialDurationFromHours() {
    if (this.args.durationHours === null) {
      this.duration = this.args.durationHours;
      this.selectedInterval = "hours";
    } else if (this.args.durationHours >= 8760) {
      this.duration = this._roundedDuration(this.args.durationHours / 365 / 24);
      this.selectedInterval = "years";
    } else if (this.args.durationHours >= 730) {
      this.duration = this._roundedDuration(this.args.durationHours / 30 / 24);
      this.selectedInterval = "months";
    } else if (this.args.durationHours >= 24) {
      this.duration = this._roundedDuration(this.args.durationHours / 24);
      this.selectedInterval = "days";
    } else if (this.args.durationHours < 1) {
      this.duration = this._roundedDuration(this.args.durationHours * 60);
      this.selectedInterval = "mins";
    } else {
      this.duration = this.args.durationHours;
      this.selectedInterval = "hours";
    }
  }

  _setInitialDurationFromMinutes() {
    if (this.args.durationMinutes >= 525600) {
      this.duration = this._roundedDuration(
        this.args.durationMinutes / 365 / 60 / 24
      );
      this.selectedInterval = "years";
    } else if (this.args.durationMinutes >= 43800) {
      this.duration = this._roundedDuration(
        this.args.durationMinutes / 30 / 60 / 24
      );
      this.selectedInterval = "months";
    } else if (this.args.durationMinutes >= 1440) {
      this.duration = this._roundedDuration(
        this.args.durationMinutes / 60 / 24
      );
      this.selectedInterval = "days";
    } else if (this.args.durationMinutes >= 60) {
      this.duration = this._roundedDuration(this.args.durationMinutes / 60);
      this.selectedInterval = "hours";
    } else {
      this.duration = this.args.durationMinutes;
      this.selectedInterval = "mins";
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

  get calculatedMinutes() {
    if (isBlank(this.duration)) {
      return null;
    }

    const duration = parseFloat(this.duration);

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
    this.args.onChange?.(this.calculatedMinutes);
  }

  @action
  onChangeDuration(event) {
    this.duration = event.target.value;
    this.args.onChange?.(this.calculatedMinutes);
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
