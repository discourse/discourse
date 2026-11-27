import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { type TrustedHTML, trustHTML } from "@ember/template";
import { isPresent } from "@ember/utils";
import type { ComponentLike } from "@glint/template";
import ComboBoxUntyped from "discourse/select-kit/components/combo-box";
import I18n, { i18n } from "discourse-i18n";

const AM_PM_REGEX = /^\s*(\d{1,2}):(\d{2})\s*(am|pm)\s*$/i;

/**
 * A date as a moment, typed by the methods this component calls so that the published
 * declarations don't import the moment types.
 */
export interface DTimeInputDate {
  hours(): number;
  minutes(): number;
  // `object`, because moment's own parameter type rejects this interface
  isSame(other: object, granularity: "day"): boolean;
  clone(): DTimeInputDate;
  startOf(unit: "day"): DTimeInputDate;
  add(amount: number, unit: "minutes"): DTimeInputDate;
  diff(other: object, unit: "minutes"): number;
}

/** A time of day. */
export interface DTimeInputTime {
  hours: number;
  minutes: number;
}

interface TimeOption {
  id: number;
  name: string;
  label: TrustedHTML | undefined;
  title: string;
}

// TODO(typescript-pending): drop once ComboBox is authored in .gts with a real
// Signature, then import it directly. Untyped .js today, so no arg/block/attr types.
const ComboBox = ComboBoxUntyped as unknown as ComponentLike<{
  Args: {
    content: TimeOption[];
    onChange: (value: number | string | null | undefined) => void;
    options: Record<string, unknown>;
    value: number | undefined;
  };
}>;

function convertMinutes(num: number) {
  return { hours: Math.floor(num / 60), minutes: num % 60 };
}

function uses12HourTime() {
  const format = i18n("dates.time", { defaultValue: "" });
  if (format) {
    return /[aA]/.test(format.replace(/\[[^\]]*\]/g, ""));
  }
  return I18n.currentLocale()?.startsWith("en");
}

function convertMinutesToString(n: number) {
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

function convertMinutesToDurationString(n: number) {
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

interface DTimeInputSignature {
  Args: {
    /**
     * The selected date; the input shows its time of day. Takes precedence over `@hours`
     * and `@minutes`.
     */
    date?: DTimeInputDate | null;

    /** The hour of the selected time, used when no `@date` is given. */
    hours?: number | string | null;

    /** The minute of the selected time, used when no `@date` is given. */
    minutes?: number | string | null;

    /** Earlier times on its day are left out, and later ones show the time since it. */
    relativeDate?: DTimeInputDate | null;

    /** Called with the picked or typed time. */
    onChange?: (time: DTimeInputTime) => void;
  };
  Element: HTMLDivElement;
}

/**
 * A dropdown for picking a time of day in 15-minute steps, which also accepts a typed
 * time such as `14:30` or `2:30 pm`.
 */
export default class DTimeInput extends Component<DTimeInputSignature> {
  get hours() {
    return isPresent(this.args.date) ? this.args.date.hours() : this.args.hours;
  }

  get minutes() {
    return isPresent(this.args.date)
      ? this.args.date.minutes()
      : this.args.minutes;
  }

  @cached
  get minimumTime() {
    if (this.args.relativeDate) {
      if (this.args.date) {
        if (!this.args.date.isSame(this.args.relativeDate, "day")) {
          return 0;
        } else {
          return (
            this.args.relativeDate.hours() * 60 +
            this.args.relativeDate.minutes()
          );
        }
      } else {
        return (
          this.args.relativeDate.hours() * 60 + this.args.relativeDate.minutes()
        );
      }
    }
  }

  get timeOptions() {
    let options = [];

    const start = this.minimumTime
      ? this.time !== undefined && this.minimumTime > this.time
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
      const name = convertMinutesToString(opt);
      let label;

      if (this.args.date && this.args.relativeDate) {
        const diff = this.args.date
          .clone()
          .startOf("day")
          .add(opt, "minutes")
          .diff(this.args.relativeDate, "minutes");

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

  get time() {
    if (isPresent(this.hours) && isPresent(this.minutes)) {
      return (
        parseInt(String(this.hours), 10) * 60 +
        parseInt(String(this.minutes), 10)
      );
    }
  }

  @action
  onFocusIn(value: unknown, event: FocusEvent) {
    if (value && event.target) {
      (event.target as HTMLInputElement).select();
    }
  }

  @action
  onChangeTime(time: number | string | null | undefined) {
    if (!isPresent(time) || !this.args.onChange) {
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
      this.args.onChange({ hours, minutes });
      return;
    }

    this.args.onChange({
      hours: convertMinutes(time as number).hours,
      minutes: convertMinutes(time as number).minutes,
    });
  }

  <template>
    <div class="d-time-input" ...attributes>
      <ComboBox
        @content={{this.timeOptions}}
        @onChange={{this.onChangeTime}}
        @options={{hash
          translatedNone="--:--"
          allowAny=true
          filterable=false
          autoInsertNoneItem=false
          translatedFilterPlaceholder="--:--"
        }}
        @value={{this.time}}
      />
    </div>
  </template>
}
