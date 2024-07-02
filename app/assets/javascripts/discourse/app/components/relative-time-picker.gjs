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

function inputValueFromMinutes(minutes) {
  if (!minutes) {
    return null;
  } else if (minutes >= 525600) {
    return roundDuration(minutes / 365 / 60 / 24);
  } else if (minutes >= 43800) {
    return roundDuration(minutes / 30 / 60 / 24);
  } else if (minutes >= 1440) {
    return roundDuration(minutes / 60 / 24);
  } else if (minutes >= 60) {
    return roundDuration(minutes / 60);
  } else {
    return minutes;
  }
}

function intervalFromMinutes(minutes) {
  if (minutes >= 525600) {
    return "years";
  } else if (minutes >= 43800) {
    return "months";
  } else if (minutes >= 1440) {
    return "days";
  } else if (minutes >= 60) {
    return "hours";
  } else {
    return "mins";
  }
}

export default class RelativeTimePicker extends Component {
  @tracked inputValue;
  @tracked duration;
  @tracked interval;

  constructor() {
    super(...arguments);
    this.initValues();
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

  minutesFromInputValueAndInterval(duration, interval) {
    if (isNaN(duration)) {
      return null;
    }

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
  initValues() {
    let minutes = this.args.durationMinutes;
    if (this.args.durationHours) {
      minutes ??= this.args.durationHours * 60;
    }

    this.inputValue = inputValueFromMinutes(minutes);

    if (this.args.durationMinutes !== undefined) {
      this.interval = intervalFromMinutes(this.args.durationMinutes);
    } else if (this.args.durationHours === null) {
      this.interval = "hours";
    } else if (this.args.durationHours !== undefined) {
      this.interval = intervalFromMinutes(this.args.durationHours * 60);
    } else {
      this.interval = "mins";
    }

    this.duration = this.minutesFromInputValueAndInterval(
      this.inputValue,
      this.interval
    );
  }

  @action
  onChangeDuration(event) {
    if (isBlank(event.target.value)) {
      this.inputValue = null;
      this.duration = null;
    } else {
      const minutes = this.minutesFromInputValueAndInterval(
        parseFloat(event.target.value),
        this.interval
      );

      this.duration = minutes;
      this.interval = intervalFromMinutes(this.duration);
      this.inputValue = inputValueFromMinutes(minutes);
    }

    this.args.onChange?.(this.duration);
  }

  @action
  onChangeInterval(interval) {
    this.interval = interval;
    this.duration = this.minutesFromInputValueAndInterval(
      this.inputValue,
      this.interval
    );
    this.args.onChange?.(this.duration);
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
