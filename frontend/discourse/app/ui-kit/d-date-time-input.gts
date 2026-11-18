import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DDateInput from "discourse/ui-kit/d-date-input";
import DTimeInput from "discourse/ui-kit/d-time-input";

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
        <DTimeInput
          @date={{this.date}}
          @onChange={{this.onChangeTime}}
          @relativeDate={{this.relativeDate}}
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
