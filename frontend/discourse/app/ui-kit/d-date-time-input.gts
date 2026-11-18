import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import withEventValue from "discourse/helpers/with-event-value";
import DButton from "discourse/ui-kit/d-button";
import DDateInput from "discourse/ui-kit/d-date-input";

/** Legacy global supplied by the application, without introducing a module import. */
declare const moment: typeof import("moment");

/**
 * A date as a moment, typed by shape so that the published declarations don't import
 * the moment types: a plugin that infers a moment from them could not name its type.
 */
export interface DDateTimeInputDate {
  year(): number;
  month(): number;
  date(): number;
  hours(): number;
  minutes(): number;
}

/** The fields of a wall-clock date and time. */
interface WallTimeFields {
  year: number;
  month: number;
  day: number;
  hours: number;
  minutes: number;
}

/** A time picked in the time input. */
interface PickedTime {
  hours: number;
  minutes: number;
}

interface DDateTimeInputSignature {
  Args: {
    /** The selected date and time. */
    date?: DDateTimeInputDate | null;

    /** The date that the pickers start from when no date is selected. */
    relativeDate?: DDateTimeInputDate | null;

    /** Whether to show the time input. Defaults to `true`. */
    showTime?: boolean;

    /** Whether to show a button that clears the value. Defaults to `false`. */
    clearable?: boolean;

    /** The timezone of the value. Defaults to the timezone of the browser. */
    timezone?: string;

    /** Whether to show the time input before the date input. */
    timeFirst?: boolean;

    /** The placeholder of the date input. */
    placeholder?: string;

    /** Whether the date picker renders in the global picker container. */
    useGlobalPickerContainer?: boolean;

    /** Called with the new date and time, or `null` when the value is cleared. */
    onChange?: (date: DDateTimeInputDate | null) => void;
  };
  Element: HTMLDivElement;
}

export default class DDateTimeInput extends Component<DDateTimeInputSignature> {
  // Subclasses read the inputs by name (`this.date`), so they stay getters.
  get date() {
    return this.args.date;
  }

  get relativeDate() {
    return this.args.relativeDate;
  }

  get showTime() {
    return this.args.showTime ?? true;
  }

  get clearable() {
    return this.args.clearable ?? false;
  }

  get hours() {
    return this.date && this.showTime ? this.date.hours() : null;
  }

  get minutes() {
    return this.date && this.showTime ? this.date.minutes() : null;
  }

  get time() {
    if (!this.date || !this.showTime) {
      return null;
    }
    const pad = (part: number) => String(part).padStart(2, "0");
    return `${pad(this.date.hours())}:${pad(this.date.minutes())}`;
  }

  get resolvedTimezone() {
    return this.args.timezone || moment.tz.guess();
  }

  @action
  onClear() {
    this.args.onChange?.(null);
  }

  @action
  onChangeTime(time: PickedTime) {
    if (this.args.onChange) {
      const date = this.date
        ? this.date
        : this.relativeDate
          ? this.relativeDate
          : moment.tz(this.resolvedTimezone);

      this.args.onChange(
        this.#atWallTime({
          year: date.year(),
          month: date.month(),
          day: date.date(),
          hours: time.hours,
          minutes: time.minutes,
        })
      );
    }
  }

  /** Reads the time input's "HH:mm"; an emptied input keeps the date's time. */
  @action
  onInputTime(value: string) {
    if (!value) {
      return;
    }
    const [hours, minutes] = value.split(":").map(Number);
    this.onChangeTime({ hours, minutes });
  }

  @action
  onChangeDate(date: DDateTimeInputDate | null) {
    if (!date) {
      this.onClear();
      return;
    }

    this.args.onChange?.(
      this.#atWallTime({
        year: date.year(),
        month: date.month(),
        day: date.date(),
        hours: this.hours || 0,
        minutes: this.minutes || 0,
      })
    );
  }

  /**
   * Without an explicit zone, use the browser's own rules. The bundled tz data
   * only covers years near the present and gets DST offsets wrong outside them.
   */
  #atWallTime(fields: WallTimeFields) {
    return this.args.timezone
      ? moment.tz(fields, this.args.timezone)
      : moment(fields);
  }

  <template>
    <div class="d-date-time-input" ...attributes>
      {{#unless @timeFirst}}
        <DDateInput
          @date={{this.date}}
          @onChange={{this.onChangeDate}}
          @placeholder={{@placeholder}}
          @relativeDate={{this.relativeDate}}
          @useGlobalPickerContainer={{@useGlobalPickerContainer}}
        />
      {{/unless}}

      {{#if this.showTime}}
        <input
          class="time-input"
          type="time"
          value={{this.time}}
          {{on "input" (withEventValue this.onInputTime)}}
        />
      {{/if}}

      {{#if @timeFirst}}
        <DDateInput
          @date={{this.date}}
          @onChange={{this.onChangeDate}}
          @placeholder={{@placeholder}}
          @relativeDate={{this.relativeDate}}
          @useGlobalPickerContainer={{@useGlobalPickerContainer}}
        />
      {{/if}}

      {{#if this.clearable}}
        <DButton
          class="btn-default clear-date-time"
          @action={{this.onClear}}
          @icon="xmark"
        />
      {{/if}}
    </div>
  </template>
}
