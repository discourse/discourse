import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { isBlank } from "@ember/utils";
import { eq } from "truth-helpers";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

const HOUR = 60;
const DAY = 24 * HOUR;
const MONTH = 30 * DAY;
const YEAR = 365 * DAY;

function roundDuration(duration) {
  let rounded = parseFloat(duration.toFixed(1));
  rounded = Math.round(rounded * 2) / 2;

  // don't show decimal point for fraction-less numbers
  return rounded % 1 === 0 ? rounded.toFixed(0) : rounded;
}

function inputValueFromMinutes(minutes) {
  if (!minutes) {
    return null;
  } else if (minutes > YEAR) {
    return roundDuration(minutes / YEAR);
  } else if (minutes > MONTH) {
    return roundDuration(minutes / MONTH);
  } else if (minutes > DAY) {
    return roundDuration(minutes / DAY);
  } else if (minutes > HOUR) {
    return roundDuration(minutes / HOUR);
  } else {
    return minutes;
  }
}

function intervalFromMinutes(minutes) {
  if (minutes > YEAR) {
    return "years";
  } else if (minutes > MONTH) {
    return "months";
  } else if (minutes > DAY) {
    return "days";
  } else if (minutes > HOUR) {
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
        name: i18n("relative_time_picker.minutes", { count }),
      },
      {
        id: "hours",
        name: i18n("relative_time_picker.hours", { count }),
      },
      {
        id: "days",
        name: i18n("relative_time_picker.days", { count }),
      },
      {
        id: "months",
        name: i18n("relative_time_picker.months", { count }),
      },
      {
        id: "years",
        name: i18n("relative_time_picker.years", { count }),
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
        return duration * HOUR;
      case "days":
        return duration * DAY;
      case "months":
        return duration * MONTH; // less accurate because of varying days in months
      case "years":
        return duration * YEAR; // least accurate because of varying days in months/years
    }
  }

  @action
  initValues() {
    let minutes = this.args.durationMinutes;
    if (this.args.durationHours) {
      minutes ??= this.args.durationHours * HOUR;
    }

    this.inputValue = inputValueFromMinutes(minutes);

    if (this.args.durationMinutes !== undefined) {
      this.interval = intervalFromMinutes(this.args.durationMinutes);
    } else if (this.args.durationHours === null) {
      this.interval = "hours";
    } else if (this.args.durationHours !== undefined) {
      this.interval = intervalFromMinutes(this.args.durationHours * HOUR);
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
      this.duration = null;
      this.inputValue = null;
    } else {
      let newDuration = this.minutesFromInputValueAndInterval(
        parseFloat(event.target.value),
        this.interval
      );

      // if on the edge of an interval - go to the next value
      // (e.g. 24 hours -> 1.5 days, instead of 24 hours -> 1 day)
      if (
        newDuration > this.duration &&
        (this.duration === YEAR ||
          this.duration === MONTH ||
          this.duration === DAY ||
          this.duration === HOUR)
      ) {
        newDuration = this.minutesFromInputValueAndInterval(
          parseFloat(event.target.value) * 1.5,
          this.interval
        );
      }

      this.duration = newDuration;
      this.interval = intervalFromMinutes(this.duration);
      this.inputValue = inputValueFromMinutes(this.duration);
    }

    this.args.onChange?.(this.duration);
  }

  @action
  onChangeInterval(interval) {
    this.interval = interval;

    const newDuration = this.minutesFromInputValueAndInterval(
      this.inputValue,
      this.interval
    );
    if (newDuration !== this.duration) {
      this.duration = newDuration;
      this.args.onChange?.(this.duration);
    }
  }

  <template>
    <div class="relative-time-picker" ...attributes>
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
