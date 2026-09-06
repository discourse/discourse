/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import { trustHTML } from "@ember/template";
import { isPresent } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import ComboBox from "discourse/select-kit/components/combo-box";
import I18n, { i18n } from "discourse-i18n";

const AM_PM_REGEX = /^\s*(\d{1,2}):(\d{2})\s*(am|pm)\s*$/i;

function convertMinutes(num) {
  return { hours: Math.floor(num / 60), minutes: num % 60 };
}

function uses12HourTime() {
  const format = i18n("dates.time", { defaultValue: "" });
  if (format) {
    return /[aA]/.test(format.replace(/\[[^\]]*\]/g, ""));
  }
  return I18n.currentLocale()?.startsWith("en");
}

function convertMinutesToString(n) {
  const { hours, minutes } = convertMinutes(n);
  if (uses12HourTime()) {
    const period = hours >= 12 ? "PM" : "AM";
    const displayHours = hours % 12 || 12;
    return `${displayHours}:${minutes.toString().padStart(2, "0")} ${period}`;
  }
  return `${hours.toString().padStart(2, "0")}:${minutes
    .toString()
    .padStart(2, "0")}`;
}

function convertMinutesToDurationString(n) {
  const hoursAndMinutes = convertMinutes(n);

  let output;

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

@tagName("")
export default class DTimeInput extends Component {
  hours = null;
  minutes = null;
  relativeDate = null;

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    if (isPresent(this.date)) {
      this.setProperties({
        hours: this.date.hours(),
        minutes: this.date.minutes(),
      });
    }

    if (
      !isPresent(this.date) &&
      !isPresent(this.hours) &&
      !isPresent(this.minutes)
    ) {
      this.setProperties({
        hours: null,
        minutes: null,
      });
    }
  }

  @computed("relativeDate", "date")
  get minimumTime() {
    if (this.relativeDate) {
      if (this.date) {
        if (!this.date.isSame(this.relativeDate, "day")) {
          return 0;
        } else {
          return this.relativeDate.hours() * 60 + this.relativeDate.minutes();
        }
      } else {
        return this.relativeDate.hours() * 60 + this.relativeDate.minutes();
      }
    }
  }

  @computed("minimumTime", "hours", "minutes")
  get timeOptions() {
    let options = [];

    const start = this.minimumTime
      ? this.minimumTime > this.time
        ? this.time
        : this.minimumTime
      : 0;

    // theres 1440 minutes in a day
    // and 1440 / 15 = 96
    let i = 0;
    let option = start;
    options.push(option);
    while (i < 95) {
      // while diff with minimumTime is less than one hour
      // use 15 minutes steps and then 30 minutes
      const minutes = this.minimumTime ? (i <= 3 ? 15 : 30) : 15;
      option = option + minutes;
      // when start is higher than 0 we will reach 1440 minutes
      // before the 95 iterations
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

    return options.map((opt) => {
      let name = convertMinutesToString(opt);
      let label;

      if (this.date && this.relativeDate) {
        const diff = this.date
          .clone()
          .startOf("day")
          .add(opt, "minutes")
          .diff(this.relativeDate, "minutes");

        if (diff < 1440) {
          label = trustHTML(
            `${name} <small>(${convertMinutesToDurationString(diff)})</small>`
          );
        }
      }

      return {
        id: opt,
        name,
        label,
        title: name,
      };
    });
  }

  @computed("minimumTime", "hours", "minutes")
  get time() {
    if (isPresent(this.hours) && isPresent(this.minutes)) {
      return parseInt(this.hours, 10) * 60 + parseInt(this.minutes, 10);
    }
  }

  @action
  onFocusIn(value, event) {
    if (value && event.target) {
      event.target.select();
    }
  }

  @action
  onChangeTime(time) {
    if (!isPresent(time) || !this.onChange) {
      return;
    }

    if (typeof time === "string" && time.length) {
      const ampmMatch = time.match(AM_PM_REGEX);

      let hours;
      let minutes;
      if (ampmMatch) {
        hours = parseInt(ampmMatch[1], 10);
        minutes = parseInt(ampmMatch[2], 10);
        const isPm = ampmMatch[3].toLowerCase() === "pm";
        if (isPm && hours !== 12) {
          hours += 12;
        } else if (!isPm && hours === 12) {
          hours = 0;
        }
      } else {
        const [h, m] = time.split(":");
        if (!h || !m) {
          return;
        }
        hours = parseInt(h, 10);
        minutes = parseInt(m, 10);
      }

      if (!Number.isFinite(hours) || !Number.isFinite(minutes)) {
        return;
      }

      hours = Math.max(0, Math.min(23, hours));
      minutes = Math.max(0, Math.min(59, minutes));
      this.onChange({ hours, minutes });
      return;
    }

    this.onChange({
      hours: convertMinutes(time).hours,
      minutes: convertMinutes(time).minutes,
    });
  }

  <template>
    <div class="d-time-input" ...attributes>
      <ComboBox
        @value={{this.time}}
        @content={{this.timeOptions}}
        @onChange={{this.onChangeTime}}
        @options={{hash
          translatedNone="--:--"
          allowAny=true
          filterable=false
          autoInsertNoneItem=false
          translatedFilterPlaceholder="--:--"
        }}
      />
    </div>
  </template>
}
