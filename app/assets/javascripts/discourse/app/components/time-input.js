import { isPresent } from "@ember/utils";
import { computed, action } from "@ember/object";
import Component from "@ember/component";

function convertMinutes(num) {
  return { hours: Math.floor(num / 60), minutes: num % 60 };
}

function convertMinutesToString(n) {
  const hoursAndMinutes = convertMinutes(n);
  return `${hoursAndMinutes.hours
    .toString()
    .padStart(2, "0")}:${hoursAndMinutes.minutes.toString().padStart(2, "0")}`;
}

function convertMinutesToDurationString(n) {
  const hoursAndMinutes = convertMinutes(n);

  let output = "";

  if (hoursAndMinutes.hours) {
    output = `${hoursAndMinutes.hours}h`;

    if (hoursAndMinutes.minutes > 0) {
      output = `${output} ${hoursAndMinutes.minutes} min`;
    }
  } else {
    output = `${hoursAndMinutes.minutes} min`;
  }

  return output;
}

export default Component.extend({
  classNames: ["d-time-input"],

  hours: null,

  minutes: null,

  relativeDate: null,

  didReceiveAttrs() {
    this._super(...arguments);

    if (isPresent(this.date)) {
      this.setProperties({
        hours: this.date.hours(),
        minutes: this.date.minutes()
      });
    }

    if (
      !isPresent(this.date) &&
      !isPresent(this.attrs.hours) &&
      !isPresent(this.attrs.minutes)
    ) {
      this.setProperties({
        hours: null,
        minutes: null
      });
    }
  },

  minimumTime: computed("relativeDate", "date", function() {
    if (this.relativeDate) {
      if (this.date) {
        if (this.date.diff(this.relativeDate, "minutes") > 1440) {
          return 0;
        } else {
          return this.relativeDate.hours() * 60 + this.relativeDate.minutes();
        }
      } else {
        return this.relativeDate.hours() * 60 + this.relativeDate.minutes();
      }
    }
  }),

  timeOptions: computed("minimumTime", "hours", "minutes", function() {
    let options = [];

    const start = this.minimumTime
      ? this.minimumTime > this.time
        ? this.time
        : this.minimumTime
      : 0;

    // theres 1440 minutes in a day
    // and 1440 / 15 = 96
    let i = 0;
    while (i < 96) {
      // while diff with minimumTime is less than one hour
      // use 15 minutes steps and then 30 minutes
      const minutes = this.minimumTime ? (i <= 4 ? 15 : 30) : 15;
      const option = start + i * minutes;

      // when start is higher than 0 we will reach 1440 minutes
      // before the 96 iterations
      if (option > 1440) {
        break;
      }

      options.push(option);

      i++;
    }

    if (this.time && !options.includes(this.time)) {
      options = [this.time].concat(options);
    }

    options = options.sort((a, b) => a - b);

    return options.map(option => {
      let name = convertMinutesToString(option);
      let label;

      if (this.minimumTime) {
        const diff = option - this.minimumTime;
        label = `${name} <small>(${convertMinutesToDurationString(
          diff
        )})</small>`.htmlSafe();
      }

      return {
        id: option,
        name,
        label,
        title: name
      };
    });
  }),

  time: computed("minimumTime", "hours", "minutes", function() {
    if (isPresent(this.hours) && isPresent(this.minutes)) {
      return parseInt(this.hours, 10) * 60 + parseInt(this.minutes, 10);
    }
  }),

  @action
  onFocusIn(value, event) {
    if (value && event.target) {
      event.target.select();
    }
  },

  @action
  onChangeTime(time) {
    if (isPresent(time) && this.onChange) {
      if (typeof time === "string" && time.length) {
        let [hours, minutes] = time.split(":");
        if (hours && minutes) {
          if (hours < 0) hours = 0;
          if (hours > 23) hours = 23;
          if (minutes < 0) minutes = 0;
          if (minutes > 59) minutes = 59;

          this.onChange({
            hours: parseInt(hours, 10),
            minutes: parseInt(minutes, 10)
          });
        }
      } else {
        this.onChange({
          hours: convertMinutes(time).hours,
          minutes: convertMinutes(time).minutes
        });
      }
    }
  }
});
